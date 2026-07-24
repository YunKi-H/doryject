//
//  CalendarViewModelDayChangeTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarViewModelDayChangeTests {
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

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!.startOfDay
    }
}

private final class CountingEventRepository: EventRepository {
    private(set) var allEventsCallCount = 0

    func save(_ event: UserEvent) {}
    func delete(id: UUID) {}
    func delete(type: EventType, on: Date) {}
    func replace(type: EventType, on dates: Set<Date>) {}

    func allEvents() -> [UserEvent] {
        allEventsCallCount += 1
        return []
    }

    func events(forMonth month: Date) -> [UserEvent] {
        []
    }

    func events(of type: EventType) -> [UserEvent] {
        []
    }
}
