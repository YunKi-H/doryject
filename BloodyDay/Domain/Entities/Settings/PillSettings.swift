//
//  PillSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct PillSettings: Codable {
    var pillEnabled: Bool = false
    var pillTime: DateComponents = .init(hour: 9, minute: 0)
    var pillSchedule: [Bool] = Array(repeating: true, count: 21) + Array(repeating: false, count: 7)
    var pillCalendarCalculationEnabled: Bool = false
    var pillAutoRecordEnabled: Bool = false
    var pillCount: Int = 21
    var pillBreakDuration: Int = 7
}
