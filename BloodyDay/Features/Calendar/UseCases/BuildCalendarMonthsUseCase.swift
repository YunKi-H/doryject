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
        buildContext: (_ bounds: (start: Date, endExclusive: Date), _ userEvents: [UserEvent]) -> Context,
        makeMonthInfo: (_ month: Date, _ userEvents: [UserEvent], _ context: Context) -> MonthInfo
    ) -> Result {
        let normalizedMonthDates = monthDates.map(\.startOfMonth)
        guard let bounds = calculationBounds(for: normalizedMonthDates) else {
            return Result(months: [], currentIndex: 0)
        }
        
        let calculationEvents = calculationEvents(in: bounds, allEvents: allEvents)
        let context = buildContext(bounds, calculationEvents)
        let months = normalizedMonthDates.map { makeMonthInfo($0, calculationEvents, context) }
        
        let resolvedIndex: Int
        if let idx = months.firstIndex(where: { $0.monthDate == keepingMonth.startOfMonth }) {
            resolvedIndex = idx
        } else {
            resolvedIndex = min(previousCurrentIndex, max(months.count - 1, 0))
        }
        
        return Result(months: months, currentIndex: resolvedIndex)
    }
    
    private static func calculationBounds(for monthDates: [Date]) -> (start: Date, endExclusive: Date)? {
        guard let firstMonth = monthDates.min(),
              let lastMonth = monthDates.max() else {
            return nil
        }
        let start = firstMonth.startOfMonth.addingMonths(-1)
        let endExclusive = lastMonth.startOfMonth.addingMonths(2)
        return (start: start, endExclusive: endExclusive)
    }
    
    private static func calculationEvents(
        in bounds: (start: Date, endExclusive: Date),
        allEvents: [UserEvent]
    ) -> [UserEvent] {
        allEvents.filter {
            let day = $0.date.startOfDay
            return day >= bounds.start && day < bounds.endExclusive
        }
    }
}
