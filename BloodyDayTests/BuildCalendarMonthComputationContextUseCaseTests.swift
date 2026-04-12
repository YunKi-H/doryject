//
//  BuildCalendarMonthComputationContextUseCaseTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 2/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct BuildCalendarMonthComputationContextUseCaseTests {
    private let calendar: Calendar = .current
    
    @Test
    func execute_buildsEventsByDayAndPillSequenceMap() {
        let day = makeDate(2030, 2, 10)
        let bounds = (start: makeDate(2030, 2, 1), endExclusive: makeDate(2030, 3, 1))
        
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let userEvents = [
            userEvent(.love, on: day),
            userEvent(.pill, on: day),
            userEvent(.period, on: addDays(day, -3))
        ]
        let allPeriodEvents = [userEvent(.period, on: addDays(day, -3))]
        let allPillDates: Set<Date> = [day]
        
        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: userEvents,
            allPeriodEvents: allPeriodEvents,
            allPillDates: allPillDates,
            settings: settings,
            today: makeDate(2030, 1, 1),
            calendar: calendar
        )
        
        let eventTypes = Set(context.eventsByDay[day, default: []].map(\.type))
        #expect(eventTypes.contains(.love))
        #expect(eventTypes.contains(.pill))
        #expect(context.pillDates == allPillDates)
        #expect(context.pillSequenceByDate[day] == 1)
    }
    
    @Test
    func execute_buildsPredictedPeriodDatesWithinBoundsFromManualAverages() {
        let firstStart = makeDate(2030, 1, 1)
        let secondStart = makeDate(2030, 1, 29) // 28-day cycle
        let bounds = (start: makeDate(2030, 2, 1), endExclusive: makeDate(2030, 4, 1))
        
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        
        let allPeriodEvents = periodRun(start: firstStart, length: 5) + periodRun(start: secondStart, length: 5)
        
        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: [],
            allPeriodEvents: allPeriodEvents,
            allPillDates: [],
            settings: settings,
            today: makeDate(2029, 12, 1), // ensure predicted are future `.period`, not `.delayed`
            calendar: calendar
        )
        
        let expectedStart = makeDate(2030, 2, 26)
        let expectedDates = Set((0..<5).map { addDays(expectedStart, $0) })
        
        for date in expectedDates {
            #expect(context.predictedPeriodDates.contains(date))
            #expect(context.predictedEventsByDay[date]?.contains(.period) == true)
        }
        
        #expect(context.predictedPeriodDates.allSatisfy { $0 >= bounds.start && $0 < bounds.endExclusive })
    }

    @Test
    func execute_alignsPillPredictionWithLatestActualPeriodAnchor() {
        let actualStart = makeDate(2026, 3, 6)
        let bounds = (start: makeDate(2026, 4, 1), endExclusive: makeDate(2026, 5, 1))

        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let allPeriodEvents = periodRun(start: actualStart, length: 5)
        let pillCycleStart = makeDate(2026, 2, 14)
        let allPillDates: Set<Date> = Set((0..<18).map { addDays(pillCycleStart, $0) })

        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: [],
            allPeriodEvents: allPeriodEvents,
            allPillDates: allPillDates,
            settings: settings,
            today: makeDate(2026, 3, 11),
            calendar: calendar
        )

        let expectedStart = makeDate(2026, 4, 3)
        let expectedDates = Set((0..<5).map { addDays(expectedStart, $0) })

        for date in expectedDates {
            #expect(context.predictedPeriodDates.contains(date))
            #expect(context.predictedEventsByDay[date]?.contains(.period) == true)
        }
    }
    
    private func userEvent(_ type: EventType, on date: Date) -> UserEvent {
        UserEvent(id: UUID(), date: date.startOfDay, type: type)
    }
    
    private func periodRun(start: Date, length: Int) -> [UserEvent] {
        (0..<length).map { offset in
            userEvent(.period, on: addDays(start, offset))
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
