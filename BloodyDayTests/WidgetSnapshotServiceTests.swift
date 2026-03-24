//
//  WidgetSnapshotServiceTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 3/24/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct WidgetSnapshotServiceTests {
    private let calendar: Calendar = .current

    @Test
    func refresh_writesPillFertilityAndPeriodChips() {
        let today = makeDate(2026, 3, 24)

        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let events = [
            UserEvent(date: today, type: .pill),
            UserEvent(date: addDays(today, -1), type: .pill),
            UserEvent(date: addDays(today, -2), type: .pill),
            UserEvent(date: addDays(today, -3), type: .pill),
            UserEvent(date: addDays(today, -4), type: .pill),
            UserEvent(date: addDays(today, -5), type: .pill),
            UserEvent(date: addDays(today, -6), type: .pill),
            UserEvent(date: addDays(today, -7), type: .pill),
            UserEvent(date: addDays(today, -8), type: .pill),
            UserEvent(date: addDays(today, -9), type: .pill),
            UserEvent(date: addDays(today, -10), type: .pill),
            UserEvent(date: addDays(today, -11), type: .pill),
            UserEvent(date: addDays(today, -12), type: .pill),
            UserEvent(date: addDays(today, -13), type: .pill),
            UserEvent(date: addDays(today, -14), type: .pill),
            UserEvent(date: addDays(today, -15), type: .pill),
            UserEvent(date: addDays(today, -16), type: .pill),
            UserEvent(date: addDays(today, -17), type: .pill),
            UserEvent(date: addDays(today, -18), type: .pill),
            UserEvent(date: addDays(today, -19), type: .pill),
            UserEvent(date: addDays(today, -20), type: .pill),
            UserEvent(date: today, type: .period),
            UserEvent(date: addDays(today, 1), type: .period),
            UserEvent(date: addDays(today, 2), type: .period),
            UserEvent(date: addDays(today, 3), type: .period),
            UserEvent(date: addDays(today, 4), type: .period)
        ]

        let repository = InMemoryEventRepository(events: events)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let store = TestWidgetSnapshotStore()
        let service = WidgetSnapshotService(
            eventRepository: repository,
            settingsRepository: settingsRepository,
            store: store.store
        )

        service.refresh(today: today, calendar: calendar)

        let snapshot = store.load()
        #expect(snapshot?.chips.map(\.kind) == [.pill, .period])
        #expect(snapshot?.chips.first?.text == "(21/21)")
        #expect(snapshot?.chips.last?.text == "진행")
    }

    @Test
    func refresh_writesExpectedPrimarySubTextFormats() {
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5

        let start = makeDate(2026, 3, 1)
        let repository = InMemoryEventRepository(
            events: (0..<5).map { UserEvent(date: addDays(start, $0), type: .period) }
        )
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let store = TestWidgetSnapshotStore()
        let service = WidgetSnapshotService(
            eventRepository: repository,
            settingsRepository: settingsRepository,
            store: store.store
        )

        let countdownDate = makeDate(2026, 3, 20)
        service.refresh(today: countdownDate, calendar: calendar)
        #expect(store.load()?.primarySubText == "(3/29 예정)")

        let ongoingDate = makeDate(2026, 3, 29)
        service.refresh(today: ongoingDate, calendar: calendar)
        #expect(store.load()?.primaryText == "B-Day")
        #expect(store.load()?.primarySubText == nil)

        let delayedDate = makeDate(2026, 4, 4)
        service.refresh(today: delayedDate, calendar: calendar)
        #expect(store.load()?.primarySubText == "(3/29 시작)")
    }

    @Test
    func refresh_skipsFertilityChipWhenNotFertile() {
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5

        let start = makeDate(2026, 3, 1)
        let repository = InMemoryEventRepository(
            events: (0..<5).map { UserEvent(date: addDays(start, $0), type: .period) }
        )
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let store = TestWidgetSnapshotStore()
        let service = WidgetSnapshotService(
            eventRepository: repository,
            settingsRepository: settingsRepository,
            store: store.store
        )

        service.refresh(today: makeDate(2026, 3, 12), calendar: calendar)

        let chipKinds = store.load()?.chips.map(\.kind) ?? []
        #expect(chipKinds.contains(.fertility) == false)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }

    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }
}

private final class InMemoryEventRepository: EventRepository {
    private var events: [UserEvent]

    init(events: [UserEvent]) {
        self.events = events
    }

    func save(_ event: UserEvent) {
        events.append(event)
    }

    func delete(id: UUID) {
        events.removeAll { $0.id == id }
    }

    func delete(type: EventType, on: Date) {
        let target = on.startOfDay
        events.removeAll { $0.type == type && $0.date.startOfDay == target }
    }

    func replace(type: EventType, on dates: Set<Date>) {
        events.removeAll { $0.type == type }
        events.append(contentsOf: dates.map { UserEvent(date: $0, type: type) })
    }

    func allEvents() -> [UserEvent] {
        events
    }

    func events(forMonth month: Date) -> [UserEvent] {
        let monthStart = month.startOfMonth
        return events.filter { $0.date.startOfMonth == monthStart }
    }

    func events(of type: EventType) -> [UserEvent] {
        events.filter { $0.type == type }
    }
}

private struct InMemorySettingsRepository: SettingsRepository {
    var settings: UserSettings

    func load() -> UserSettings {
        settings
    }

    func save(_ settings: UserSettings) {}
}

private final class TestWidgetSnapshotStoreBox {
    var snapshot: WidgetSnapshot?
}

private struct TestWidgetSnapshotStore {
    let box = TestWidgetSnapshotStoreBox()

    var store: WidgetSnapshotStore {
        WidgetSnapshotStore(
            loadHandler: { box.snapshot },
            saveHandler: { box.snapshot = $0 }
        )
    }

    func load() -> WidgetSnapshot? {
        box.snapshot
    }
}
