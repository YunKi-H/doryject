//
//  AppleCalendarSyncServiceTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 3/19/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct AppleCalendarSyncServiceTests {
    private let calendar: Calendar = .current

    @Test
    func syncAll_addsActualAndPredictedPeriodSummariesForNextYear() async {
        let today = makeDate(2026, 3, 19)
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        settings.appleCalendar.isEnabled = true
        settings.appleCalendar.eventSyncEnabled[.period] = true

        let events = makeEvents(type: .period, start: makeDate(2026, 3, 1), length: 5)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let eventRepository = StaticEventRepository(events: events)
        let client = RecordingAppleCalendarClient(calendarIdentifier: "period-calendar")
        let store = InMemoryAppleCalendarSyncStore()
        let service = AppleCalendarSyncService(
            settingsRepository: settingsRepository,
            eventRepository: eventRepository,
            calendarClient: client,
            syncStore: store,
            nowProvider: { today }
        )

        await service.syncAll()

        let periodEvents = client.upsertedEvents.filter { $0.calendarIdentifier == "period-calendar" }
        #expect(periodEvents.count == 14)
        #expect(periodEvents.contains(where: { $0.start == makeDate(2026, 3, 1) && $0.end == makeDate(2026, 3, 5).endOfDay }))
        #expect(periodEvents.contains(where: { $0.start == makeDate(2026, 3, 29) && $0.end == makeDate(2026, 4, 2).endOfDay }))
        #expect(periodEvents.contains(where: { $0.start == makeDate(2027, 2, 28) && $0.end == makeDate(2027, 3, 4).endOfDay }))
    }

    @Test
    func syncAll_skipsPredictedCycleWhenActualFuturePeriodAlreadyExists() async {
        let today = makeDate(2026, 3, 19)
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        settings.appleCalendar.isEnabled = true
        settings.appleCalendar.eventSyncEnabled[.period] = true

        let events =
            makeEvents(type: .period, start: makeDate(2026, 3, 1), length: 5) +
            makeEvents(type: .period, start: makeDate(2026, 3, 29), length: 5)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let eventRepository = StaticEventRepository(events: events)
        let client = RecordingAppleCalendarClient(calendarIdentifier: "period-calendar")
        let store = InMemoryAppleCalendarSyncStore()
        let service = AppleCalendarSyncService(
            settingsRepository: settingsRepository,
            eventRepository: eventRepository,
            calendarClient: client,
            syncStore: store,
            nowProvider: { today }
        )

        await service.syncAll()

        let starts = client.upsertedEvents.map(\.start)
        #expect(starts.filter { $0 == makeDate(2026, 3, 29) }.count == 1)
        #expect(starts.contains(makeDate(2026, 4, 26)))
    }

    private func makeEvents(type: EventType, start: Date, length: Int) -> [UserEvent] {
        (0..<length).map { offset in
            UserEvent(
                id: UUID(),
                date: addDays(start, offset),
                type: type,
                calendar: calendar
            )
        }
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }

    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }
}

private final class InMemorySettingsRepository: SettingsRepository {
    private var current: UserSettings

    init(settings: UserSettings) {
        self.current = settings
    }

    func load() -> UserSettings { current }

    func save(_ settings: UserSettings) {
        current = settings
    }
}

private struct StaticEventRepository: EventRepository {
    let events: [UserEvent]

    func save(_ event: UserEvent) {}
    func delete(id: UUID) {}
    func delete(type: EventType, on: Date) {}
    func replace(type: EventType, on dates: Set<Date>) {}
    func allEvents() -> [UserEvent] { events }
    func events(forMonth month: Date) -> [UserEvent] { events }
    func events(of type: EventType) -> [UserEvent] { events.filter { $0.type == type } }
}

private final class InMemoryAppleCalendarSyncStore: AppleCalendarSyncStore {
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

private final class RecordingAppleCalendarClient: AppleCalendarClient {
    struct UpsertedEvent {
        let eventId: UUID
        let calendarIdentifier: String
        let title: String
        let start: Date
        let end: Date
    }

    private let fixedCalendarIdentifier: String
    private(set) var upsertedEvents: [UpsertedEvent] = []

    init(calendarIdentifier: String) {
        self.fixedCalendarIdentifier = calendarIdentifier
    }

    func requestAccess() async -> Bool { true }

    func createOrFetchCalendar(name: String, existingIdentifier: String?) -> String? {
        existingIdentifier ?? fixedCalendarIdentifier
    }

    func removeCalendar(identifier: String) {}

    func upsertEvent(
        event: UserEvent,
        calendarIdentifier: String,
        title: String,
        existingEventIdentifier: String?,
        dateRange: DateInterval?
    ) -> String? {
        let start = dateRange?.start.startOfDay ?? event.date.startOfDay
        let end = dateRange?.end ?? event.date.endOfDay
        upsertedEvents.append(
            UpsertedEvent(
                eventId: event.id,
                calendarIdentifier: calendarIdentifier,
                title: title,
                start: start,
                end: end
            )
        )
        return existingEventIdentifier ?? "ek-\(event.id.uuidString)"
    }

    func deleteEvent(identifier: String) {}
}
