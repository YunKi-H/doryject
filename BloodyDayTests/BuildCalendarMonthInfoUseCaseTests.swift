//
//  BuildCalendarMonthInfoUseCaseTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 2/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct BuildCalendarMonthInfoUseCaseTests {
    private let calendar: Calendar = .current
    
    @Test
    func execute_buildsFixed42DayGridAndMergesPredictedEventsAndPillSequence() {
        let month = makeDate(2026, 2, 1)
        let pillDate = makeDate(2026, 2, 10)
        let predictedDate = makeDate(2026, 2, 12)
        
        let context = MonthComputationContext(
            eventsByDay: [
                pillDate: [DayEvent(type: .pill)],
                predictedDate: [DayEvent(type: .love)]
            ],
            pillDates: [pillDate],
            pillSequenceByDate: [pillDate: 3],
            predictedEventsByDay: [predictedDate: [.period]],
            predictedPeriodDates: [predictedDate]
        )
        
        let monthInfo = BuildCalendarMonthInfoUseCase.execute(
            month: month,
            userEvents: [UserEvent(id: UUID(), date: pillDate, type: .pill)],
            context: context
        )
        
        #expect(monthInfo.days.count == 42)
        
        let pillDay = monthInfo.days.first { $0.date.isSameDay(as: pillDate) }
        #expect(pillDay?.pillSequence == 3)
        #expect(pillDay?.events.contains(where: { $0.type == .pill }) == true)
        
        let mergedDay = monthInfo.days.first { $0.date.isSameDay(as: predictedDate) }
        #expect(mergedDay?.events.contains(where: { $0.type == .love }) == true)
        #expect(mergedDay?.events.contains(where: { $0.type == .period }) == true)
        #expect(monthInfo.predictedPeriodDates.contains(predictedDate))
    }
    
    @Test
    func execute_dimsRunsWhoseStartAndEndAreOutsideCurrentMonth() {
        let month = makeDate(2026, 2, 1)
        let jan26 = makeDate(2026, 1, 26)
        let jan27 = makeDate(2026, 1, 27)
        let jan28 = makeDate(2026, 1, 28)
        
        let context = MonthComputationContext(
            eventsByDay: [:],
            pillDates: [],
            pillSequenceByDate: [:],
            predictedEventsByDay: [
                jan26: [.fertile],
                jan27: [.fertile, .ovulation],
                jan28: [.fertile]
            ],
            predictedPeriodDates: []
        )
        
        let monthInfo = BuildCalendarMonthInfoUseCase.execute(
            month: month,
            userEvents: [],
            context: context
        )
        
        #expect(monthInfo.fertileRanges.isEmpty == false)
        #expect(monthInfo.ovulationRanges.isEmpty == false)
        #expect(monthInfo.fertileRanges.allSatisfy { $0.opacity == 0.3 })
        #expect(monthInfo.ovulationRanges.allSatisfy { $0.opacity == 0.3 })
    }
    
    @Test
    func execute_keepsOpacityFullForRunsTouchingCurrentMonth() {
        let month = makeDate(2026, 2, 1)
        let jan31 = makeDate(2026, 1, 31)
        let feb1 = makeDate(2026, 2, 1)
        let feb2 = makeDate(2026, 2, 2)
        
        let context = MonthComputationContext(
            eventsByDay: [:],
            pillDates: [],
            pillSequenceByDate: [:],
            predictedEventsByDay: [
                jan31: [.period],
                feb1: [.period],
                feb2: [.period]
            ],
            predictedPeriodDates: [jan31, feb1, feb2]
        )
        
        let monthInfo = BuildCalendarMonthInfoUseCase.execute(
            month: month,
            userEvents: [],
            context: context
        )
        
        #expect(monthInfo.predictedPeriodRanges.isEmpty == false)
        #expect(monthInfo.predictedPeriodRanges.allSatisfy { $0.opacity == 1.0 })
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }
}
