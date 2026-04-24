//
//  TestDoubles.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/23/26.
//

import CloudKit
import Foundation
import Testing
@testable import BloodyDay

private struct WaitUntilTimeoutError: Error {}

func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    _ condition: @escaping () async -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(Double(timeoutNanoseconds) / 1_000_000_000)
    while await condition() == false {
        try await Task.sleep(nanoseconds: 10_000_000)
        if Date() > deadline {
            Issue.record("Timed out waiting for condition")
            throw WaitUntilTimeoutError()
        }
    }
}

final class InMemorySettingsRepository: SettingsRepository {
    private var current: UserSettings

    init(settings: UserSettings) {
        self.current = settings
    }

    func load() -> UserSettings {
        current
    }

    func save(_ settings: UserSettings) {
        current = settings
    }
}

struct StaticEventRepository: EventRepository {
    let events: [UserEvent]

    init(events: [UserEvent] = []) {
        self.events = events
    }

    func save(_ event: UserEvent) {}
    func delete(id: UUID) {}
    func delete(type: EventType, on: Date) {}
    func replace(type: EventType, on dates: Set<Date>) {}
    func allEvents() -> [UserEvent] { events }
    func events(forMonth month: Date) -> [UserEvent] { events }
    func events(of type: EventType) -> [UserEvent] { events.filter { $0.type == type } }
}

final class RecordingEventRepository: EventRepository {
    private var storedEvents: [UserEvent]

    init(events: [UserEvent] = []) {
        self.storedEvents = events
    }

    func save(_ event: UserEvent) {
        storedEvents.removeAll { $0.id == event.id }
        storedEvents.append(event)
    }

    func delete(id: UUID) {
        storedEvents.removeAll { $0.id == id }
    }

    func delete(type: EventType, on date: Date) {
        let target = date.startOfDay
        storedEvents.removeAll { $0.type == type && $0.date.startOfDay == target }
    }

    func replace(type: EventType, on dates: Set<Date>) {
        let normalizedDates = Set(dates.map(\.startOfDay))
        storedEvents.removeAll { $0.type == type }
        storedEvents.append(
            contentsOf: normalizedDates.map {
                UserEvent(date: $0, type: type)
            }
        )
    }

    func allEvents() -> [UserEvent] {
        storedEvents
    }

    func events(forMonth month: Date) -> [UserEvent] {
        storedEvents
    }

    func events(of type: EventType) -> [UserEvent] {
        storedEvents.filter { $0.type == type }
    }
}

final class NoopAppleCalendarClient: AppleCalendarClient {
    func requestAccess() async -> Bool { false }
    func createOrFetchCalendar(name: String, existingIdentifier: String?) -> String? { nil }
    func removeCalendar(identifier: String) {}
    func upsertEvent(
        event: UserEvent,
        calendarIdentifier: String,
        title: String,
        existingEventIdentifier: String?,
        dateRange: DateInterval?
    ) -> String? {
        nil
    }
    func deleteEvent(identifier: String) {}
}

final class InMemoryAppleCalendarSyncStore: AppleCalendarSyncStore {
    private var recordsById: [UUID: AppleCalendarSyncRecord] = [:]

    func record(for eventId: UUID) -> AppleCalendarSyncRecord? {
        recordsById[eventId]
    }

    func records() -> [AppleCalendarSyncRecord] {
        Array(recordsById.values)
    }

    func upsert(_ record: AppleCalendarSyncRecord) {
        recordsById[record.userEventId] = record
    }

    func remove(for eventId: UUID) {
        recordsById.removeValue(forKey: eventId)
    }

    func removeAll() {
        recordsById.removeAll()
    }
}

final class InMemorySharedCalendarRepository: SharedCalendarRepository, SharedCalendarManaging, SharedCalendarReloading {
    private var storedCalendars: [SharedCalendar]
    private var storedEventsByCalendarID: [String: [SharedCalendarEvent]]
    private(set) var removedCalendarIDs: [String] = []
    private(set) var refreshCallCount = 0

    init(
        calendars: [SharedCalendar] = [],
        eventsByCalendarID: [String: [SharedCalendarEvent]] = [:]
    ) {
        self.storedCalendars = calendars
        self.storedEventsByCalendarID = eventsByCalendarID
    }

    func calendars() -> [SharedCalendar] {
        storedCalendars
    }

    func calendar(id: String) -> SharedCalendar? {
        storedCalendars.first { $0.id == id }
    }

    func events(calendarId: String) -> [SharedCalendarEvent] {
        storedEventsByCalendarID[calendarId] ?? []
    }

    func updateLocalDisplayName(calendarId: String, name: String?) {
        guard let index = storedCalendars.firstIndex(where: { $0.id == calendarId }) else { return }
        storedCalendars[index].localDisplayName = name
    }

    func removeLocalCalendar(calendarId: String) {
        removedCalendarIDs.append(calendarId)
        storedCalendars.removeAll { $0.id == calendarId }
        storedEventsByCalendarID.removeValue(forKey: calendarId)
    }

    func replaceCalendars(_ calendars: [SharedCalendar]) {
        storedCalendars = calendars
    }

    @MainActor
    func refresh() async {
        refreshCallCount += 1
    }
}

actor TestCloudSharingService: CloudSharingService {
    struct SyncSnapshot {
        let sharedEventTypes: SharedEventTypeSelection
        let settings: UserSettings
        let eventIDs: [UUID]
    }

    nonisolated let containerIdentifier = "iCloud.test.BDay"
    var availability: CloudSharingAvailability = .available
    var ownedShare: CKShare?
    var preparedShare: PreparedCloudShare?
    var stopOwnedSharingError: Error?
    var leaveSharedCalendarError: Error?
    var syncDelayNanoseconds: UInt64 = 0
    var blockedSyncCallNumbers: Set<Int> = []
    var sharedSnapshot = SharedCalendarSnapshot(calendars: [], eventsByCalendarId: [:])
    private(set) var didStopOwnedSharing = false
    private(set) var leftCalendarIDs: [String] = []
    private(set) var lastPreparedSharedEventTypes: SharedEventTypeSelection?
    private(set) var lastPreparedSettings: UserSettings?
    private(set) var lastPreparedEvents: [UserEvent] = []
    private(set) var ownedEventSyncStartedCount = 0
    private(set) var ownedEventSyncCallCount = 0
    private(set) var lastSyncedSharedEventTypes: SharedEventTypeSelection?
    private(set) var lastSyncedSettings: UserSettings?
    private(set) var lastSyncedEvents: [UserEvent] = []
    private(set) var syncSnapshots: [SyncSnapshot] = []
    private var blockedSyncContinuations: [CheckedContinuation<Void, Never>] = []

    func fetchAvailability() async -> CloudSharingAvailability {
        availability
    }

    func accept(_ metadata: CKShare.Metadata) async throws {}

    func fetchSharedSnapshot() async throws -> SharedCalendarSnapshot {
        sharedSnapshot
    }

    func fetchOwnedShare() async throws -> CKShare? {
        ownedShare
    }

    func stopOwnedSharing() async throws {
        if let stopOwnedSharingError {
            throw stopOwnedSharingError
        }
        didStopOwnedSharing = true
    }

    func leaveSharedCalendar(_ calendar: SharedCalendar) async throws {
        if let leaveSharedCalendarError {
            throw leaveSharedCalendarError
        }
        leftCalendarIDs.append(calendar.id)
    }

    func prepareOwnedShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> PreparedCloudShare {
        lastPreparedSharedEventTypes = sharedEventTypes
        lastPreparedSettings = settings
        lastPreparedEvents = events
        return preparedShare ?? PreparedCloudShare(
            share: CKShare(rootRecord: CKRecord(recordType: SharedCloudKitSchema.calendarRecordType)),
            eventSyncResult: .synced
        )
    }

    func syncOwnedEventsIfNeeded(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> CloudSharingEventSyncResult {
        ownedEventSyncStartedCount += 1
        if blockedSyncCallNumbers.contains(ownedEventSyncStartedCount) {
            await withCheckedContinuation { continuation in
                blockedSyncContinuations.append(continuation)
            }
        }
        if syncDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: syncDelayNanoseconds)
        }
        ownedEventSyncCallCount += 1
        lastSyncedSharedEventTypes = sharedEventTypes
        lastSyncedSettings = settings
        lastSyncedEvents = events
        syncSnapshots.append(
            SyncSnapshot(
                sharedEventTypes: sharedEventTypes,
                settings: settings,
                eventIDs: events.map(\.id)
            )
        )
        return .synced
    }

    func releaseBlockedSyncs() {
        let continuations = blockedSyncContinuations
        blockedSyncContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func setBlockedSyncCallNumbers(_ numbers: Set<Int>) {
        blockedSyncCallNumbers = numbers
    }

    func setAvailability(_ value: CloudSharingAvailability) {
        availability = value
    }

    func setOwnedShare(_ value: CKShare?) {
        ownedShare = value
    }

    func setPreparedShare(_ value: PreparedCloudShare?) {
        preparedShare = value
    }

    func setSharedSnapshot(_ value: SharedCalendarSnapshot) {
        sharedSnapshot = value
    }

    func setStopOwnedSharingError(_ value: Error?) {
        stopOwnedSharingError = value
    }

    func setLeaveSharedCalendarError(_ value: Error?) {
        leaveSharedCalendarError = value
    }

    func syncSnapshotsCount() -> Int {
        syncSnapshots.count
    }

    func lastSyncSnapshot() -> SyncSnapshot? {
        syncSnapshots.last
    }

    func firstSyncSnapshot() -> SyncSnapshot? {
        syncSnapshots.first
    }

    func ownedEventSyncStartedCountValue() -> Int {
        ownedEventSyncStartedCount
    }

    func ownedEventSyncCallCountValue() -> Int {
        ownedEventSyncCallCount
    }

    func lastPreparedSharedEventTypesValue() -> SharedEventTypeSelection? {
        lastPreparedSharedEventTypes
    }

    func lastPreparedSettingsValue() -> UserSettings? {
        lastPreparedSettings
    }

    func lastPreparedEventIDs() -> [UUID] {
        lastPreparedEvents.map(\.id)
    }

    func leftCalendarIDsValue() -> [String] {
        leftCalendarIDs
    }

    func didStopOwnedSharingValue() -> Bool {
        didStopOwnedSharing
    }
}

final class TestCloudSharingSyncScheduler: CloudSharingSyncScheduling {
    struct ScheduledRequest {
        let settings: UserSettings
        let eventIDs: [UUID]
    }

    private let onSchedule: ((UserSettings, [UserEvent]) -> Void)?
    private(set) var scheduledRequests: [ScheduledRequest] = []

    init(onSchedule: ((UserSettings, [UserEvent]) -> Void)? = nil) {
        self.onSchedule = onSchedule
    }

    convenience init(cloudSharingService: CloudSharingService) {
        self.init { settings, events in
            Task {
                _ = try? await cloudSharingService.syncOwnedEventsIfNeeded(
                    sharedEventTypes: settings.calendarSharing.defaultSharedEventTypes,
                    settings: settings,
                    events: events
                )
            }
        }
    }

    func schedule(settings: UserSettings, events: [UserEvent]) {
        scheduledRequests.append(
            ScheduledRequest(
                settings: settings,
                eventIDs: events.map(\.id)
            )
        )
        onSchedule?(settings, events)
    }

    func scheduledRequestsCount() -> Int {
        scheduledRequests.count
    }

    func lastScheduledRequest() -> ScheduledRequest? {
        scheduledRequests.last
    }
}
