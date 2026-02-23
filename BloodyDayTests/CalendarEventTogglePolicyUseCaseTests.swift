//
//  CalendarEventTogglePolicyUseCaseTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 2/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarEventTogglePolicyUseCaseTests {
    private let calendar: Calendar = .current
    
    @Test
    func mutationPlan_periodOffDeletesFromSelectedToContiguousRunEnd() {
        let d1 = makeDate(2026, 2, 10)
        let d2 = addDays(d1, 1)
        let d3 = addDays(d1, 2)
        let d4 = addDays(d1, 3)
        
        let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
            type: .period,
            enabled: false,
            selectedDate: d2,
            existingDatesByType: [.period: Set([d1, d2, d3, d4])],
            settings: .init(),
            calendar: calendar
        )
        
        #expect(plan.additions.isEmpty)
        #expect(plan.deletions == [CalendarEventMutation(type: .period, dates: [d2, d3, d4])])
    }
    
    @Test
    func mutationPlan_periodOnAdjacentAddsOnlySelectedDate() {
        let target = makeDate(2026, 2, 12)
        let existingPeriod = Set([addDays(target, -1)])
        
        let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
            type: .period,
            enabled: true,
            selectedDate: target,
            existingDatesByType: [.period: existingPeriod],
            settings: .init(),
            calendar: calendar
        )
        
        #expect(plan.deletions.isEmpty)
        #expect(plan.additions == [CalendarEventMutation(type: .period, dates: [target])])
    }
    
    @Test
    func mutationPlan_periodOnNonAdjacentAddsPredictedLengthUsingManualAverage() {
        let target = makeDate(2026, 2, 12)
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averagePeriodDays = 3
        
        let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
            type: .period,
            enabled: true,
            selectedDate: target,
            existingDatesByType: [:],
            settings: settings,
            calendar: calendar
        )
        
        #expect(plan.additions == [
            CalendarEventMutation(type: .period, dates: [target, addDays(target, 1), addDays(target, 2)])
        ])
        #expect(plan.deletions.isEmpty)
    }
    
    @Test
    func mutationPlan_pillOnWithAutoRecordAddsUntilCycleReachesPillCount() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 5
        settings.pill.pillBreakDuration = 2
        
        let start = makeDate(2026, 2, 10)
        // Existing same cycle has 3 dates (10,11,13); turning ON on 12 should fill 12 and 14 to reach 5 total.
        let pillDates: Set<Date> = [start, addDays(start, 1), addDays(start, 3)]
        
        let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
            type: .pill,
            enabled: true,
            selectedDate: addDays(start, 2),
            existingDatesByType: [.pill: Set(pillDates)],
            settings: settings,
            calendar: calendar
        )
        
        #expect(plan.deletions.isEmpty)
        #expect(plan.additions == [
            CalendarEventMutation(type: .pill, dates: [addDays(start, 2), addDays(start, 4)])
        ])
    }
    
    @Test
    func pillDisableConfirmationPlan_returnsContextForAutoRecordCurrentCycleWithRemainingDates() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let cycleStart = makeDate(2026, 2, 1)
        let cycleDates = Set((0...4).map { addDays(cycleStart, $0) })
        let selected = addDays(cycleStart, 2)
        
        let plan = CalendarEventTogglePolicyUseCase.pillDisableConfirmationPlan(
            selectedDate: selected,
            pillDates: cycleDates,
            settings: settings,
            calendar: calendar
        )
        
        #expect(plan?.remainingCount == 2)
        #expect(plan?.todayOnlyDeleteDates == [selected])
        #expect(plan?.stopCycleDeleteDates == [selected, addDays(selected, 1), addDays(selected, 2)])
    }
    
    @Test
    func pillDisableConfirmationPlan_returnsNilWhenNoRemainingDatesAfterSelected() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let cycleStart = makeDate(2026, 2, 1)
        let cycleDates = Set((0...2).map { addDays(cycleStart, $0) })
        let selected = addDays(cycleStart, 2)
        
        let plan = CalendarEventTogglePolicyUseCase.pillDisableConfirmationPlan(
            selectedDate: selected,
            pillDates: cycleDates,
            settings: settings,
            calendar: calendar
        )
        
        #expect(plan == nil)
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }
    
    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }
}
