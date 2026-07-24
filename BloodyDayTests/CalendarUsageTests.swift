//
//  CalendarUsageTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarUsageTests {
    @Test
    func periodSummaryUsesInjectedCalendarForDayGrouping() {
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let morning = losAngeles.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 1,
                hour: 1
            )
        )!
        let evening = losAngeles.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 1,
                hour: 20
            )
        )!

        let summaries = PeriodSummaryBuilder.build(
            from: [morning, evening],
            calendar: losAngeles
        )

        #expect(summaries.count == 1)
        #expect(summaries.first?.lengthDays == 1)
        #expect(
            losAngeles.component(.day, from: summaries[0].start) == 1
        )
    }

    @Test
    func dateSequenceUsesInjectedCalendarAcrossDaylightSavingChange() {
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let start = losAngeles.date(
            from: DateComponents(year: 2026, month: 3, day: 7)
        )!
        let endExclusive = losAngeles.date(
            from: DateComponents(year: 2026, month: 3, day: 11)
        )!

        let dates = Date.dates(
            from: start,
            toExclusive: endExclusive,
            calendar: losAngeles
        )

        #expect(dates.count == 4)
        #expect(
            dates.allSatisfy {
                losAngeles.component(.hour, from: $0) == 0
            }
        )
        #expect(
            dates.map { losAngeles.component(.day, from: $0) }
                == [7, 8, 9, 10]
        )
    }

    @Test
    func monthAssemblyUsesInjectedCalendarForGridDates() {
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let month = losAngeles.date(
            from: DateComponents(year: 2026, month: 7, day: 15)
        )!
        let context = MonthComputationContext(
            eventsByDay: [:],
            pillDates: [],
            pillSequenceByDate: [:],
            predictedEventsByDay: [:],
            predictedPeriodDates: []
        )

        let result = BuildCalendarMonthInfoUseCase.execute(
            month: month,
            userEvents: [],
            context: context,
            calendar: losAngeles
        )

        #expect(result.days.count == 42)
        #expect(
            result.days.allSatisfy {
                losAngeles.component(.hour, from: $0.date) == 0
            }
        )
        #expect(losAngeles.component(.month, from: result.monthDate) == 7)
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }
}
