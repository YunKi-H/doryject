//
//  BuildCalendarMonthsUseCase.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

enum BuildCalendarMonthsUseCase {
    struct Result {
        let months: [MonthInfo]
        let currentIndex: Int
    }
    
    static func execute<Context>(
        monthDates: [Date],
        keepingMonth: Date,
        previousCurrentIndex: Int,
        allEvents: [UserEvent],
        calendar: Calendar = .current,
        buildContext: (_ bounds: (start: Date, endExclusive: Date), _ userEvents: [UserEvent]) -> Context,
        makeMonthInfo: (_ month: Date, _ userEvents: [UserEvent], _ context: Context) -> MonthInfo
    ) -> Result {
        let normalizedMonthDates = monthDates.map {
            $0.startOfMonth(in: calendar)
        }
        guard let bounds = calculationBounds(
            for: normalizedMonthDates,
            calendar: calendar
        ) else {
            return Result(months: [], currentIndex: 0)
        }
        
        let calculationEvents = calculationEvents(
            in: bounds,
            allEvents: allEvents,
            calendar: calendar
        )
        let context = buildContext(bounds, calculationEvents)
        let months = normalizedMonthDates.map { makeMonthInfo($0, calculationEvents, context) }
        
        let resolvedIndex: Int
        let normalizedKeepingMonth = keepingMonth.startOfMonth(in: calendar)
        if let idx = months.firstIndex(where: {
            $0.monthDate == normalizedKeepingMonth
        }) {
            resolvedIndex = idx
        } else {
            resolvedIndex = min(previousCurrentIndex, max(months.count - 1, 0))
        }
        
        return Result(months: months, currentIndex: resolvedIndex)
    }
    
    private static func calculationBounds(
        for monthDates: [Date],
        calendar: Calendar
    ) -> (start: Date, endExclusive: Date)? {
        guard let firstMonth = monthDates.min(),
              let lastMonth = monthDates.max() else {
            return nil
        }
        let start = firstMonth
            .startOfMonth(in: calendar)
            .addingMonths(-1, calendar: calendar)
        let endExclusive = lastMonth
            .startOfMonth(in: calendar)
            .addingMonths(2, calendar: calendar)
        return (start: start, endExclusive: endExclusive)
    }
    
    private static func calculationEvents(
        in bounds: (start: Date, endExclusive: Date),
        allEvents: [UserEvent],
        calendar: Calendar
    ) -> [UserEvent] {
        allEvents.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= bounds.start && day < bounds.endExclusive
        }
    }
}
