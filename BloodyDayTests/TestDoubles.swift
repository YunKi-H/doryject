//
//  TestDoubles.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/23/26.
//

import CloudKit
import Foundation
@testable import BloodyDay

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

final class TestCloudSharingService: CloudSharingService {
    let containerIdentifier = "iCloud.test.BDay"
    var availability: CloudSharingAvailability = .available
    var ownedShare: CKShare?
    var preparedShare: PreparedCloudShare?
    var stopOwnedSharingError: Error?
    var leaveSharedCalendarError: Error?
    var sharedSnapshot = SharedCalendarSnapshot(calendars: [], eventsByCalendarId: [:])
    private(set) var didStopOwnedSharing = false
    private(set) var leftCalendarIDs: [String] = []
    private(set) var lastPreparedSharedEventTypes: SharedEventTypeSelection?
    private(set) var lastPreparedSettings: UserSettings?
    private(set) var lastPreparedEvents: [UserEvent] = []

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
}
