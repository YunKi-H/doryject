//
//  DayInfoCardStatusUseCaseTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 2/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct DayInfoCardStatusUseCaseTests {
    private let calendar: Calendar = .current
    
    @Test
    func primaryStatus_returnsBDayOnActualPeriodStart() {
        let date = makeDate(2026, 2, 10)
        let settings = UserSettings()
        
        let status = DayInfoCardStatusUseCase.primaryStatus(
            for: date,
            today: date,
            periodDates: [date, addDays(date, 1), addDays(date, 2)],
            pillDates: [],
            settings: settings,
            calendar: calendar
        )
        
        #expect(status == .bDay)
    }
    
    @Test
    func primaryStatus_usesManualCyclePredictionForCountdownAndDelayed() {
        let periodStart = makeDate(2026, 1, 1)
        let periodDates = [
            periodStart,
            addDays(periodStart, 1),
            addDays(periodStart, 2),
            addDays(periodStart, 3),
            addDays(periodStart, 4)
        ]
        
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        
        let countdownTarget = makeDate(2026, 1, 20)
        let countdown = DayInfoCardStatusUseCase.primaryStatus(
            for: countdownTarget,
            today: countdownTarget,
            periodDates: periodDates,
            pillDates: [],
            settings: settings,
            calendar: calendar
        )
        #expect(countdown == .countdown(days: 9))
        
        let delayedTarget = makeDate(2026, 1, 30)
        let delayed = DayInfoCardStatusUseCase.primaryStatus(
            for: delayedTarget,
            today: delayedTarget,
            periodDates: periodDates,
            pillDates: [],
            settings: settings,
            calendar: calendar
        )
        #expect(delayed == .ongoing(day: 2))
        
        let delayedAfterEndTarget = makeDate(2026, 2, 4)
        let delayedAfterEnd = DayInfoCardStatusUseCase.primaryStatus(
            for: delayedAfterEndTarget,
            today: delayedAfterEndTarget,
            periodDates: periodDates,
            pillDates: [],
            settings: settings,
            calendar: calendar
        )
        #expect(delayedAfterEnd == .delayed(days: 6))
    }

    @Test
    func primaryStatus_changesFromOngoingToDelayedAfterPredictedPeriodEnds() {
        let periodStart = makeDate(2026, 1, 1)
        let periodDates = (0..<5).map { addDays(periodStart, $0) }
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5

        let lastPredictedPeriodDate = makeDate(2026, 2, 2)
        let ongoing = DayInfoCardStatusUseCase.primaryStatus(
            for: lastPredictedPeriodDate,
            today: lastPredictedPeriodDate,
            periodDates: periodDates,
            pillDates: [],
            settings: settings,
            calendar: calendar
        )
        let firstDelayedDate = makeDate(2026, 2, 3)
        let delayed = DayInfoCardStatusUseCase.primaryStatus(
            for: firstDelayedDate,
            today: firstDelayedDate,
            periodDates: periodDates,
            pillDates: [],
            settings: settings,
            calendar: calendar
        )

        #expect(ongoing == .ongoing(day: 5))
        #expect(delayed == .delayed(days: 5))
    }
    
    @Test
    func primaryStatus_hidesBeforeLatestActualPeriodStart() {
        let oldStart = makeDate(2026, 1, 1)
        let latestStart = makeDate(2026, 2, 10)
        let periodDates = [
            oldStart, addDays(oldStart, 1), addDays(oldStart, 2),
            latestStart, addDays(latestStart, 1), addDays(latestStart, 2)
        ]
        
        let status = DayInfoCardStatusUseCase.primaryStatus(
            for: makeDate(2026, 2, 1),
            today: makeDate(2026, 2, 20),
            periodDates: periodDates,
            pillDates: [],
            settings: .init(),
            calendar: calendar
        )
        
        #expect(status == .unknown)
    }

    @Test
    func primaryStatus_prefersLatestActualPeriodOverStalePillPrediction() {
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let actualStart = makeDate(2026, 3, 6)
        let periodDates = (0..<5).map { addDays(actualStart, $0) }

        let pillCycleStart = makeDate(2026, 2, 14)
        let pillDates: Set<Date> = Set((0..<18).map { addDays(pillCycleStart, $0) }) // projected first expected = 3/6

        let status = DayInfoCardStatusUseCase.primaryStatus(
            for: makeDate(2026, 3, 11),
            today: makeDate(2026, 3, 11),
            periodDates: periodDates,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )

        #expect(status == .countdown(days: 23))
    }

    @Test
    func primaryStatus_usesSharedForecastWhenLatestActualPeriodOverridesPillAnchor() {
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = true
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let periodDates =
            (0..<4).map { addDays(makeDate(2026, 3, 2), $0) } +
            (0..<5).map { addDays(makeDate(2026, 3, 19), $0) }
        let pillDates: Set<Date> = Set((0..<21).map { addDays(makeDate(2026, 3, 9), $0) })

        let status = DayInfoCardStatusUseCase.primaryStatus(
            for: makeDate(2026, 4, 5),
            today: makeDate(2026, 3, 19),
            periodDates: periodDates,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )

        #expect(status == .bDay)
    }
    
    @Test
    func secondaryStatus_returnsPillWhenExactPillEventExists() {
        let target = makeDate(2026, 2, 10)
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let pillDates: Set<Date> = [
            makeDate(2026, 2, 8),
            makeDate(2026, 2, 9),
            target
        ]
        
        let status = DayInfoCardStatusUseCase.secondaryStatus(
            for: target,
            allEventsEmpty: false,
            isPillEnabled: true,
            dayEvents: nil,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        
        #expect(status == .pill(day: 3, total: 21))
    }
    
    @Test
    func secondaryStatus_autoRecordOnDoesNotSynthesizeStaleFuturePillLabel() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let cycleStart = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = Set((0...11).map { addDays(cycleStart, $0) }) // interrupted at day 12
        let targetWithoutEvent = makeDate(2026, 2, 20) // would previously synthesize 20/21 in some cases
        
        let status = DayInfoCardStatusUseCase.secondaryStatus(
            for: targetWithoutEvent,
            allEventsEmpty: false,
            isPillEnabled: true,
            dayEvents: nil,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        
        #expect(status == .notFertile)
    }
    
    @Test
    func secondaryStatus_autoRecordOnStillShowsBreakAfterActualLastIntake() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let cycleStart = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = Set((0...11).map { addDays(cycleStart, $0) }) // last intake = 2/12
        let breakDay2 = makeDate(2026, 2, 14) // 2nd break day
        
        let status = DayInfoCardStatusUseCase.secondaryStatus(
            for: breakDay2,
            allEventsEmpty: false,
            isPillEnabled: true,
            dayEvents: nil,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        
        #expect(status == .pillBreak(day: 2, total: 7))
    }

    @Test
    func secondaryStatus_autoRecordOnEndsBreakWhenNextCycleStartsEarly() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let firstCycleStart = makeDate(2026, 2, 1)
        let secondCycleStart = makeDate(2026, 2, 17) // 5-day gap from 2/12 -> new cycle under 4-day rule
        let pillDates: Set<Date> = Set((0...11).map { addDays(firstCycleStart, $0) })
            .union([secondCycleStart])

        let formerBreakDay = makeDate(2026, 2, 17)

        let status = DayInfoCardStatusUseCase.secondaryStatus(
            for: formerBreakDay,
            allEventsEmpty: false,
            isPillEnabled: true,
            dayEvents: nil,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )

        #expect(status == .pill(day: 1, total: 21))
    }
    
    @Test
    func secondaryStatus_fallsBackToFertilityEventWhenNoPillStatus() {
        let status = DayInfoCardStatusUseCase.secondaryStatus(
            for: makeDate(2026, 2, 10),
            allEventsEmpty: false,
            isPillEnabled: false,
            dayEvents: [DayEvent(type: .ovulation)],
            pillDates: [],
            settings: .init(),
            calendar: calendar
        )
        
        #expect(status == .ovulation)
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }
    
    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }
}
