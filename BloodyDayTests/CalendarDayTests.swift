//
//  CalendarDayTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarDayTests {
    @Test
    func dayKeyRoundTripPreservesCivilDay() throws {
        let original = try #require(
            CalendarDay(year: 2026, month: 7, day: 24)
        )

        let restored = try #require(
            CalendarDay(dayKey: original.dayKey)
        )

        #expect(restored == original)
        #expect(restored.dayKey == 20260724)
        #expect(restored.dateString == "2026-07-24")
    }

    @Test
    func dateResolutionPreservesCivilDayAcrossTimeZones() throws {
        let seoul = calendar(timeZoneIdentifier: "Asia/Seoul")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let recordedDate = try #require(
            seoul.date(
                from: DateComponents(year: 2026, month: 7, day: 24)
            )
        )
        let calendarDay = CalendarDay(date: recordedDate, calendar: seoul)

        let resolvedDate = try #require(calendarDay.date(in: losAngeles))
        let components = losAngeles.dateComponents(
            [.year, .month, .day],
            from: resolvedDate
        )

        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 24)
    }

    @Test
    func invalidCivilDayIsRejected() {
        #expect(CalendarDay(year: 2026, month: 2, day: 29) == nil)
        #expect(CalendarDay(dayKey: 20260229) == nil)
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }
}
