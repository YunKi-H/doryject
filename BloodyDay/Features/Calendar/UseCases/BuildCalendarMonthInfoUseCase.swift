//
//  BuildCalendarMonthInfoUseCase.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

enum BuildCalendarMonthInfoUseCase {
    static func execute(
        month: Date,
        userEvents: [UserEvent],
        context: MonthComputationContext
    ) -> MonthInfo {
        let monthStart = month.startOfMonth
        let actualPeriodDates = Set(userEvents.filter { $0.type == .period }.map { $0.date.startOfDay })
        let result = buildDayInfos(for: monthStart, context: context)
        let days = result.days
        let predictedPeriodDates = result.predictedPeriodDates
        
        let periodRanges = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            actualPeriodDates.contains(day.date.startOfDay)
        }
        let predictedPeriodRanges = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            predictedPeriodDates.contains(day.date.startOfDay)
        }
        let delayedRanges: [CalendarRangeInfo] = []
        let fertileRanges = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            day.events.contains { $0.type == .fertile }
        }
        let rawOvulationRanges = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            day.events.contains { $0.type == .ovulation }
        }
        let ovulationRanges: [CalendarRangeInfo] = rawOvulationRanges.map { ovulation in
            let ovulationDate = ovulation.range.start.startOfDay
            guard let opacity = fertileOpacity(containing: ovulationDate, fertileRanges: fertileRanges) else {
                return ovulation
            }
            return CalendarRangeInfo(range: ovulation.range, opacity: opacity)
        }
        
        return MonthInfo(
            monthDate: monthStart,
            days: days,
            periodRanges: periodRanges,
            predictedPeriodRanges: predictedPeriodRanges,
            predictedPeriodDates: predictedPeriodDates,
            delayedRanges: delayedRanges,
            fertileRanges: fertileRanges,
            ovulationRanges: ovulationRanges
        )
    }
    
    private static func buildDayInfos(
        for month: Date,
        context: MonthComputationContext
    ) -> (days: [DayInfo], predictedPeriodDates: Set<Date>) {
        let gridStart = month.startOfCalendarGrid()
        let gridEndExclusive = month.endOfCalendarGridExclusiveStart()
        
        var days: [DayInfo] = Date.dates(from: gridStart, toExclusive: gridEndExclusive).map { DayInfo(date: $0) }
        
        for i in days.indices {
            let key = days[i].date.startOfDay
            days[i].events = context.eventsByDay[key] ?? []
        }
        
        let predictedPeriodDates = Set(
            context.predictedPeriodDates.filter { $0 >= gridStart && $0 < gridEndExclusive }
        )
        
        if !context.predictedEventsByDay.isEmpty {
            for i in days.indices {
                let key = days[i].date.startOfDay
                guard key >= gridStart && key < gridEndExclusive,
                      let predicted = context.predictedEventsByDay[key] else { continue }
                for type in predicted where !days[i].events.contains(where: { $0.type == type }) {
                    days[i].events.append(DayEvent(type: type))
                }
            }
        }
        
        for i in days.indices {
            let dayDate = days[i].date.startOfDay
            guard context.pillDates.contains(dayDate) else {
                days[i].pillSequence = nil
                continue
            }
            days[i].pillSequence = context.pillSequenceByDate[dayDate]
        }
        
        return (days, predictedPeriodDates)
    }
    
    private static func buildStyledRangesSplittingByWeeks(
        days: [DayInfo],
        monthDate: Date,
        hasEvent: (DayInfo) -> Bool,
        columns: Int = 7
    ) -> [CalendarRangeInfo] {
        var ranges: [CalendarRangeInfo] = []
        var idx = 0
        
        while idx < days.count {
            guard hasEvent(days[idx]) else {
                idx += 1
                continue
            }
            
            let runStartIndex = idx
            var runEndIndex = idx
            while runEndIndex + 1 < days.count && hasEvent(days[runEndIndex + 1]) {
                runEndIndex += 1
            }
            
            let runOpacity = opacityForRun(
                runStartDate: days[runStartIndex].date,
                runEndDate: days[runEndIndex].date,
                monthDate: monthDate
            )
            
            var segmentStartIndex = runStartIndex
            while segmentStartIndex <= runEndIndex {
                let rowEndIndex = ((segmentStartIndex / columns) * columns) + (columns - 1)
                let segmentEndIndex = min(runEndIndex, rowEndIndex)
                ranges.append(
                    CalendarRangeInfo(
                        range: DateInterval(start: days[segmentStartIndex].date, end: days[segmentEndIndex].date),
                        opacity: runOpacity
                    )
                )
                segmentStartIndex = segmentEndIndex + 1
            }
            
            idx = runEndIndex + 1
        }
        
        return ranges
    }
    
    private static func opacityForRun(runStartDate: Date, runEndDate: Date, monthDate: Date) -> Double {
        let isOutsideCurrentMonth =
        !runStartDate.isInSameMonth(as: monthDate) &&
        !runEndDate.isInSameMonth(as: monthDate)
        return isOutsideCurrentMonth ? 0.3 : 1
    }
    
    private static func fertileOpacity(containing date: Date, fertileRanges: [CalendarRangeInfo]) -> Double? {
        fertileRanges.first {
            date >= $0.range.start.startOfDay && date <= $0.range.end.startOfDay
        }?.opacity
    }
}
