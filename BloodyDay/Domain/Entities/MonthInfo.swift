//
//  MonthInfo.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import Foundation

struct CalendarRangeInfo: Equatable, Hashable {
    let range: DateInterval
    let opacity: Double
}

struct MonthInfo: Identifiable, Equatable {
    var id: Date { monthDate }
    let monthDate: Date
    let days: [DayInfo]
    let periodRanges: [CalendarRangeInfo]
    let predictedPeriodRanges: [CalendarRangeInfo]
    let predictedPeriodDates: Set<Date>
    let delayedRanges: [CalendarRangeInfo]
    let fertileRanges: [CalendarRangeInfo]
    let ovulationRanges: [CalendarRangeInfo]
}
