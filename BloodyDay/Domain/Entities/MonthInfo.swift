//
//  MonthInfo.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import Foundation

struct MonthInfo: Identifiable, Equatable {
    var id: Date { monthDate }
    let monthDate: Date
    let days: [DayInfo]
    let periodRanges: [DateInterval]
    let predictedPeriodRanges: [DateInterval]
    let predictedPeriodDates: Set<Date>
    let delayedRanges: [DateInterval]
    let fertileRanges: [DateInterval]
    let ovulationRanges: [DateInterval]
}
