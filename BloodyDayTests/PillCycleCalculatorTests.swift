//
//  PillCycleCalculatorTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 2/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct PillCycleCalculatorTests {
    private let calendar: Calendar = .current
    
    @Test
    func groupedCycles_groupsContiguousDatesIntoOneCycle() {
        let start = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = [start, addDays(start, 1), addDays(start, 2)]
        
        let cycles = PillCycleCalculator.groupedCycles(
            pillDates: pillDates,
            breakDays: 7,
            calendar: calendar
        )
        
        #expect(cycles.count == 1)
        #expect(cycles.first?.count == 3)
        #expect(cycles.first?.first == start)
        #expect(cycles.first?.last == addDays(start, 2))
    }
    
    @Test
    func groupedCycles_keepsSameCycleWhenGapIsWithinBreakDaysPlusOne() {
        let start = makeDate(2026, 2, 1)
        let breakDays = 7
        let allowedGap = breakDays + 1
        let second = addDays(start, allowedGap)
        
        let cycles = PillCycleCalculator.groupedCycles(
            pillDates: [start, second],
            breakDays: breakDays,
            calendar: calendar
        )
        
        #expect(cycles.count == 1)
        #expect(cycles.first?.count == 2)
    }
    
    @Test
    func groupedCycles_splitsCycleWhenGapExceedsBreakDaysPlusOne() {
        let start = makeDate(2026, 2, 1)
        let breakDays = 7
        let second = addDays(start, breakDays + 2)
        
        let cycles = PillCycleCalculator.groupedCycles(
            pillDates: [start, second],
            breakDays: breakDays,
            calendar: calendar
        )
        
        #expect(cycles.count == 2)
        #expect(cycles[0] == [start])
        #expect(cycles[1] == [second])
    }
    
    @Test
    func groupedCycles_doesNotForceSplitAtPillCountBoundary() {
        let start = makeDate(2026, 2, 1)
        let pillDates = Set((0..<23).map { addDays(start, $0) }) // 23 consecutive dates
        
        let cycles = PillCycleCalculator.groupedCycles(
            pillDates: pillDates,
            breakDays: 7,
            calendar: calendar
        )
        
        #expect(cycles.count == 1)
        #expect(cycles.first?.count == 23)
    }
    
    @Test
    func sequenceMap_continuesBeyondPillCount() {
        let start = makeDate(2026, 2, 1)
        let pillDates = Set((0..<23).map { addDays(start, $0) })
        
        let sequence = PillCycleCalculator.sequenceMap(
            pillDates: pillDates,
            pillCount: 21,
            breakDays: 7,
            calendar: calendar
        )
        
        #expect(sequence[addDays(start, 20)] == 21)
        #expect(sequence[addDays(start, 21)] == 22)
        #expect(sequence[addDays(start, 22)] == 23)
    }
    
    @Test
    func latestCycle_returnsMostRecentGroupedCycle() {
        let firstCycleStart = makeDate(2026, 1, 1)
        let secondCycleStart = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = [
            firstCycleStart, addDays(firstCycleStart, 1),
            secondCycleStart, addDays(secondCycleStart, 1), addDays(secondCycleStart, 2)
        ]
        
        let latest = PillCycleCalculator.latestCycle(
            pillDates: pillDates,
            breakDays: 7,
            calendar: calendar
        )
        
        #expect(latest?.first == secondCycleStart)
        #expect(latest?.count == 3)
    }
    
    @Test
    func cycleContaining_returnsCycleForTargetDate() {
        let cycleStart = makeDate(2026, 2, 1)
        let otherStart = makeDate(2026, 3, 1)
        let pillDates: Set<Date> = [
            cycleStart, addDays(cycleStart, 1), addDays(cycleStart, 2),
            otherStart, addDays(otherStart, 1)
        ]
        
        let cycle = PillCycleCalculator.cycle(
            containing: addDays(cycleStart, 1),
            pillDates: pillDates,
            breakDays: 7,
            calendar: calendar
        )
        
        #expect(cycle?.first == cycleStart)
        #expect(cycle?.count == 3)
    }
    
    @Test
    func cycleContaining_returnsNilForDateNotInAnyCycle() {
        let start = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = [start, addDays(start, 1)]
        
        let cycle = PillCycleCalculator.cycle(
            containing: addDays(start, 10),
            pillDates: pillDates,
            breakDays: 7,
            calendar: calendar
        )
        
        #expect(cycle == nil)
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }
    
    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }
}
