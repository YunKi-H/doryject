//
//  CalendarViewModelRefreshTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarViewModelRefreshTests {
    private let calendar = Calendar.current

    @Test
    func refreshIfReferenceDayChangedRebuildsMonthsOnlyAfterDayChanges() {
        let repository = CountingEventRepository()
        let firstDay = makeDate(2026, 7, 24)
        let viewModel = CalendarViewModel(
            eventRepository: repository,
            now: firstDay
        )
        let initialFetchCount = repository.allEventsCallCount

        viewModel.refreshIfReferenceDayChanged(
            now: calendar.date(byAdding: .hour, value: 12, to: firstDay)!
        )

        #expect(repository.allEventsCallCount == initialFetchCount)
        #expect(viewModel.referenceToday == firstDay)

        let nextDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!.startOfDay
        viewModel.refreshIfReferenceDayChanged(now: nextDay)

        #expect(repository.allEventsCallCount == initialFetchCount + 1)
        #expect(viewModel.referenceToday == nextDay)
        #expect(viewModel.selectedDate == firstDay)
    }

    @Test
    func systemCalendarChangePreservesSelectedCivilDay() {
        let seoul = calendar(timeZoneIdentifier: "Asia/Seoul")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let selectedDay = seoul.date(
            from: DateComponents(year: 2026, month: 7, day: 24)
        )!
        let viewModel = CalendarViewModel(
            eventRepository: CountingEventRepository(),
            now: selectedDay,
            calendar: seoul
        )
        let newNow = losAngeles.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 24,
                hour: 12
            )
        )!

        viewModel.refreshForSystemCalendarChange(
            now: newNow,
            calendar: losAngeles
        )

        let selectedComponents = losAngeles.dateComponents(
            [.year, .month, .day],
            from: viewModel.selectedDate
        )
        #expect(selectedComponents.year == 2026)
        #expect(selectedComponents.month == 7)
        #expect(selectedComponents.day == 24)
        #expect(
            losAngeles.component(
                .month,
                from: viewModel.months[viewModel.currentIndex].monthDate
            ) == 7
        )
    }

    @Test
    func statusReadsReuseCapturedComputationSnapshotUntilRefresh() {
        let today = makeDate(2026, 7, 24)
        let repository = CountingEventRepository(
            events: [
                UserEvent(
                    date: today,
                    type: .period,
                    calendar: calendar
                ),
                UserEvent(
                    date: today,
                    type: .love,
                    calendar: calendar
                )
            ]
        )
        let settingsRepository = CountingSettingsRepository()
        let viewModel = CalendarViewModel(
            eventRepository: repository,
            settingsRepository: settingsRepository,
            now: today,
            calendar: calendar
        )
        let initialAllEventsCallCount = repository.allEventsCallCount
        let initialPillCyclesCallCount = repository.pillCyclesCallCount
        let initialSettingsLoadCount = settingsRepository.loadCallCount

        _ = viewModel.primaryStatus(for: today)
        _ = viewModel.secondaryStatus(for: today)
        _ = viewModel.toggleStatesForSelectedDate()
        #expect(viewModel.isEventOnSelectedDate(.love))

        #expect(repository.allEventsCallCount == initialAllEventsCallCount)
        #expect(repository.eventsOfCallCount == 0)
        #expect(repository.pillCyclesCallCount == initialPillCyclesCallCount)
        #expect(settingsRepository.loadCallCount == initialSettingsLoadCount)

        viewModel.refresh(now: today)

        #expect(repository.allEventsCallCount == initialAllEventsCallCount + 1)
        #expect(repository.eventsOfCallCount == 0)
        #expect(repository.pillCyclesCallCount == initialPillCyclesCallCount + 1)
        #expect(settingsRepository.loadCallCount == initialSettingsLoadCount + 1)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!.startOfDay
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }
}

private final class CountingEventRepository: EventRepository {
    private(set) var allEventsCallCount = 0
    private(set) var eventsOfCallCount = 0
    private(set) var pillCyclesCallCount = 0
    private let storedEvents: [UserEvent]

    init(events: [UserEvent] = []) {
        self.storedEvents = events
    }

    func save(_ event: UserEvent) {}
    func delete(id: UUID) {}
    func delete(type: EventType, on: Date) {}
    func replace(type: EventType, on dates: Set<Date>) {}

    func allEvents() -> [UserEvent] {
        allEventsCallCount += 1
        return storedEvents
    }

    func events(forMonth month: Date) -> [UserEvent] {
        []
    }

    func events(of type: EventType) -> [UserEvent] {
        eventsOfCallCount += 1
        return storedEvents.filter { $0.type == type }
    }

    func pillCycles() -> [PillCycleInfo] {
        pillCyclesCallCount += 1
        return []
    }
}

private final class CountingSettingsRepository: SettingsRepository {
    private(set) var loadCallCount = 0
    private var settings = UserSettings()

    func load() -> UserSettings {
        loadCallCount += 1
        return settings
    }

    func save(_ settings: UserSettings) {
        self.settings = settings
    }
}
