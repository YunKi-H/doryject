//
//  PredictedCycleEventBuilderTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/12/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct PredictedCycleEventBuilderTests {
    private let calendar: Calendar = .current
    
    @Test
    func buildEvents_expandsPredictedStartsIntoPeriodFertileAndOvulationEvents() {
        let predictedStart = makeDate(2026, 4, 29)
        let eventsByDay = PredictedCycleEventBuilder.buildEvents(
            predictedPeriodStarts: [predictedStart],
            rangeStart: makeDate(2026, 4, 1),
            rangeEndExclusive: makeDate(2026, 5, 15),
            predictedLengthDays: 5,
            today: makeDate(2026, 4, 1),
            calendar: calendar
        )
        
        #expect(eventsByDay[makeDate(2026, 4, 29)]?.contains(.period) == true)
        #expect(eventsByDay[makeDate(2026, 5, 3)]?.contains(.period) == true)
        #expect(eventsByDay[makeDate(2026, 4, 15)]?.contains(.ovulation) == true)
        #expect(eventsByDay[makeDate(2026, 4, 10)]?.contains(.fertile) == true)
    }
    
    @Test
    func buildEvents_marksPastPredictedPeriodDaysAsDelayed() {
        let predictedStart = makeDate(2026, 4, 1)
        let eventsByDay = PredictedCycleEventBuilder.buildEvents(
            predictedPeriodStarts: [predictedStart],
            rangeStart: makeDate(2026, 4, 1),
            rangeEndExclusive: makeDate(2026, 4, 10),
            predictedLengthDays: 5,
            today: makeDate(2026, 4, 4),
            calendar: calendar
        )
        
        #expect(eventsByDay[makeDate(2026, 4, 1)]?.contains(.delayed) == true)
        #expect(eventsByDay[makeDate(2026, 4, 3)]?.contains(.delayed) == true)
        #expect(eventsByDay[makeDate(2026, 4, 4)]?.contains(.period) == true)
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }
}
