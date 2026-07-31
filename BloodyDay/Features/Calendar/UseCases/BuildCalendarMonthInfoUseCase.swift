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
        context: MonthComputationContext,
        calendar: Calendar = .autoupdatingCurrent
    ) -> MonthInfo {
        let monthStart = month.startOfMonth(in: calendar)
        let actualPeriodDates = Set(
            userEvents
                .filter { $0.type == .period }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let result = buildDayInfos(
            for: monthStart,
            context: context,
            calendar: calendar
        )
        let days = result.days
        let predictedPeriodDates = result.predictedPeriodDates
        
        let periodRanges = buildStyledRangesSplittingByWeeks(
            days: days,
            monthDate: monthStart,
            calendar: calendar
        ) { day in
            actualPeriodDates.contains(calendar.startOfDay(for: day.date))
        }
        let predictedPeriodRanges = buildStyledRangesSplittingByWeeks(
            days: days,
            monthDate: monthStart,
            calendar: calendar
        ) { day in
            predictedPeriodDates.contains(calendar.startOfDay(for: day.date))
        }
        let delayedRanges: [CalendarRangeInfo] = []
        let fertileRanges = buildStyledRangesSplittingByWeeks(
            days: days,
            monthDate: monthStart,
            calendar: calendar
        ) { day in
            day.events.contains { $0.type == .fertile }
        }
        let rawOvulationRanges = buildStyledRangesSplittingByWeeks(
            days: days,
            monthDate: monthStart,
            calendar: calendar
        ) { day in
            day.events.contains { $0.type == .ovulation }
        }
        let ovulationRanges: [CalendarRangeInfo] = rawOvulationRanges.map { ovulation in
            let ovulationDate = calendar.startOfDay(for: ovulation.range.start)
            guard let opacity = fertileOpacity(
                containing: ovulationDate,
                fertileRanges: fertileRanges,
                calendar: calendar
            ) else {
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
        context: MonthComputationContext,
        calendar: Calendar
    ) -> (days: [DayInfo], predictedPeriodDates: Set<Date>) {
        let gridStart = month.startOfCalendarGrid(calendar: calendar)
        let gridEndExclusive = month.endOfCalendarGridExclusiveStart(
            calendar: calendar
        )
        
        var days: [DayInfo] = Date.dates(
            from: gridStart,
            toExclusive: gridEndExclusive,
            calendar: calendar
        ).map { DayInfo(date: $0) }
        
        for i in days.indices {
            let key = calendar.startOfDay(for: days[i].date)
            days[i].events = context.eventsByDay[key] ?? []
        }
        
        let predictedPeriodDates = Set(
            context.predictedPeriodDates.filter { $0 >= gridStart && $0 < gridEndExclusive }
        )
        
        if !context.predictedEventsByDay.isEmpty {
            for i in days.indices {
                let key = calendar.startOfDay(for: days[i].date)
                guard key >= gridStart && key < gridEndExclusive,
                      let predicted = context.predictedEventsByDay[key] else { continue }
                for type in predicted where !days[i].events.contains(where: { $0.type == type }) {
                    days[i].events.append(DayEvent(type: type))
                }
            }
        }
        
        for i in days.indices {
            let dayDate = calendar.startOfDay(for: days[i].date)
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
        calendar: Calendar,
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
                monthDate: monthDate,
                calendar: calendar
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
    
    private static func opacityForRun(
        runStartDate: Date,
        runEndDate: Date,
        monthDate: Date,
        calendar: Calendar
    ) -> Double {
        let isOutsideCurrentMonth =
            !runStartDate.isInSameMonth(as: monthDate, calendar: calendar)
            && !runEndDate.isInSameMonth(as: monthDate, calendar: calendar)
        return isOutsideCurrentMonth ? 0.3 : 1
    }
    
    private static func fertileOpacity(
        containing date: Date,
        fertileRanges: [CalendarRangeInfo],
        calendar: Calendar
    ) -> Double? {
        fertileRanges.first {
            date >= calendar.startOfDay(for: $0.range.start)
                && date <= calendar.startOfDay(for: $0.range.end)
        }?.opacity
    }
}
