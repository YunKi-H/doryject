//
//  CalendarDisplayEventRepositoryTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarDisplayEventRepositoryTests {
    private let calendar = Calendar.current

    @Test
    func sharedEventsReplaceLocalDisplayAndBlockMutations() throws {
        let localDate = makeDate(2026, 7, 1)
        let sharedDate = makeDate(2026, 7, 8)
        let localRepository = RecordingDisplayEventRepository(
            events: [UserEvent(date: localDate, type: .love, calendar: calendar)]
        )
        let repository = CalendarDisplayEventRepository(
            localRepository: localRepository,
            runtimeStore: makeRuntimeStore(),
            calendar: calendar
        )
        let sharedDay = CalendarDay(date: sharedDate, calendar: calendar)
        let sharedEventID = UUID()

        repository.prepareSharedCalendar(
            connectionID: "shared-calendar",
            computationSettings: nil
        )
        repository.displaySharedCalendar(
            events: [
                SharedCalendarEvent(
                    id: sharedEventID,
                    day: sharedDay,
                    type: .period
                )
            ]
        )
        repository.save(
            UserEvent(date: sharedDate, type: .pill, calendar: calendar)
        )
        repository.delete(type: .period, on: sharedDate)

        let displayedEvent = try #require(repository.allEvents().first)
        #expect(repository.isDisplayingSharedCalendar)
        #expect(repository.allEvents().count == 1)
        #expect(displayedEvent.id == sharedEventID)
        #expect(displayedEvent.type == .period)
        #expect(displayedEvent.calendarDay == sharedDay)
        #expect(localRepository.saveCallCount == 0)
        #expect(localRepository.deleteCallCount == 0)
    }

    @Test
    func returningToLocalCalendarRestoresLocalEventsAndMutations() {
        let localDate = makeDate(2026, 7, 1)
        let localRepository = RecordingDisplayEventRepository(
            events: [UserEvent(date: localDate, type: .love, calendar: calendar)]
        )
        let repository = CalendarDisplayEventRepository(
            localRepository: localRepository,
            runtimeStore: makeRuntimeStore(),
            calendar: calendar
        )
        repository.prepareSharedCalendar(
            connectionID: "shared-calendar",
            computationSettings: nil
        )
        repository.displaySharedCalendar(events: [])

        repository.displayLocalCalendar()
        repository.save(
            UserEvent(date: localDate, type: .pill, calendar: calendar)
        )

        #expect(repository.isDisplayingSharedCalendar == false)
        #expect(repository.allEvents().map(\.type) == [.love])
        #expect(localRepository.saveCallCount == 1)
    }

    @Test
    func cachedViewerStateKeepsSharedCalendarAndOwnerSettingsOffline() {
        let runtimeStore = makeRuntimeStore()
        let sharedDate = makeDate(2026, 7, 8)
        var pillSettings = PillSettings()
        pillSettings.pillEnabled = true
        pillSettings.pillCount = 24
        pillSettings.pillBreakDuration = 4
        let computationSettings = SharedCalendarComputationSettings(
            period: PeriodSettings(
                autoCyclePredictionEnabled: true,
                averageCycleDays: 31,
                averagePeriodDays: 6
            ),
            pill: pillSettings
        )
        let initialRepository = CalendarDisplayEventRepository(
            localRepository: RecordingDisplayEventRepository(events: []),
            runtimeStore: runtimeStore,
            calendar: calendar
        )
        initialRepository.prepareSharedCalendar(
            connectionID: "shared-calendar",
            computationSettings: computationSettings
        )
        initialRepository.displaySharedCalendar(
            events: [
                SharedCalendarEvent(
                    id: UUID(),
                    day: CalendarDay(date: sharedDate, calendar: calendar),
                    type: .period
                )
            ]
        )

        let restoredRepository = CalendarDisplayEventRepository(
            localRepository: RecordingDisplayEventRepository(
                events: [UserEvent(date: sharedDate, type: .love)]
            ),
            runtimeStore: runtimeStore,
            calendar: calendar
        )
        let restoredSettings = restoredRepository.load()

        #expect(restoredRepository.isDisplayingSharedCalendar)
        #expect(restoredRepository.allEvents().map(\.type) == [.period])
        #expect(restoredSettings.period.averageCycleDays == 31)
        #expect(restoredSettings.period.averagePeriodDays == 6)
        #expect(restoredSettings.pill.pillCount == 24)
        #expect(restoredSettings.pill.pillBreakDuration == 4)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }

    private func makeRuntimeStore() -> CalendarSharingRuntimeStore {
        let suiteName = "CalendarDisplayEventRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return CalendarSharingRuntimeStore(defaults: defaults)
    }
}

private final class RecordingDisplayEventRepository: EventRepository {
    private let events: [UserEvent]
    private(set) var saveCallCount = 0
    private(set) var deleteCallCount = 0

    init(events: [UserEvent]) {
        self.events = events
    }

    func save(_ event: UserEvent) {
        saveCallCount += 1
    }

    func delete(id: UUID) {
        deleteCallCount += 1
    }

    func delete(type: EventType, on: Date) {
        deleteCallCount += 1
    }

    func replace(type: EventType, on dates: Set<Date>) {}

    func allEvents() -> [UserEvent] {
        events
    }

    func events(forMonth month: Date) -> [UserEvent] {
        events
    }

    func events(of type: EventType) -> [UserEvent] {
        events.filter { $0.type == type }
    }
}
