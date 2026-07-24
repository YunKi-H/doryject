//
//  PillReminderScheduleCalculatorTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct PillReminderScheduleCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func upcomingIntakeDates_startsWithRemainingDatesInCurrentCycle() {
        let cycleStart = makeDate(2026, 7, 1)
        let projection = makeProjection(
            cycleStart: cycleStart,
            projectedLastIntakeDate: addDays(cycleStart, 20)
        )

        let dates = PillReminderScheduleCalculator.upcomingIntakeDates(
            projection: projection,
            from: addDays(cycleStart, 4),
            count: 3,
            calendar: calendar
        )

        #expect(dates == [
            addDays(cycleStart, 4),
            addDays(cycleStart, 5),
            addDays(cycleStart, 6)
        ])
    }

    @Test
    func upcomingIntakeDates_skipsBreakAndStartsAtNextCycle() {
        let cycleStart = makeDate(2026, 7, 1)
        let projectedLastIntake = addDays(cycleStart, 20)
        let projection = makeProjection(
            cycleStart: cycleStart,
            projectedLastIntakeDate: projectedLastIntake
        )

        let dates = PillReminderScheduleCalculator.upcomingIntakeDates(
            projection: projection,
            from: addDays(projectedLastIntake, 3),
            count: 3,
            calendar: calendar
        )

        #expect(dates == [
            addDays(projectedLastIntake, 8),
            addDays(projectedLastIntake, 9),
            addDays(projectedLastIntake, 10)
        ])
    }

    @Test
    func upcomingIntakeDates_usesProjectedCompletionAfterMissedIntakes() {
        let cycleStart = makeDate(2026, 7, 1)
        let projectedLastIntake = addDays(cycleStart, 22)
        let projection = makeProjection(
            cycleStart: cycleStart,
            projectedLastIntakeDate: projectedLastIntake
        )

        let dates = PillReminderScheduleCalculator.upcomingIntakeDates(
            projection: projection,
            from: addDays(cycleStart, 20),
            count: 3,
            calendar: calendar
        )

        #expect(dates == [
            addDays(cycleStart, 20),
            addDays(cycleStart, 21),
            addDays(cycleStart, 22)
        ])
    }

    @Test
    func upcomingIntakeDates_continuesIntoNextCycleAfterCurrentCycleEnds() {
        let cycleStart = makeDate(2026, 7, 1)
        let projectedLastIntake = addDays(cycleStart, 20)
        let projection = makeProjection(
            cycleStart: cycleStart,
            projectedLastIntakeDate: projectedLastIntake
        )

        let dates = PillReminderScheduleCalculator.upcomingIntakeDates(
            projection: projection,
            from: addDays(projectedLastIntake, -1),
            count: 4,
            calendar: calendar
        )

        #expect(dates == [
            addDays(projectedLastIntake, -1),
            projectedLastIntake,
            addDays(projectedLastIntake, 8),
            addDays(projectedLastIntake, 9)
        ])
    }

    private func makeProjection(
        cycleStart: Date,
        projectedLastIntakeDate: Date
    ) -> PillCycleProjection {
        PillCycleProjection(
            cycleStart: cycleStart,
            lastIntakeDate: projectedLastIntakeDate,
            intakeCount: 21,
            projectedLastIntakeDate: projectedLastIntakeDate,
            pillCount: 21,
            breakDays: 7
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }
}
