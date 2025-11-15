//
//  MonthInfo.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import Foundation

struct MonthInfo: Identifiable, Equatable {
    let id: UUID = .init()
    let monthDate: Date
    let days: [DayInfo]
    let periodRanges: [DateInterval]
    let predictedRanges: [DateInterval]
    let fertileRanges: [DateInterval]
    let ovulationRanges: [DateInterval]
}
