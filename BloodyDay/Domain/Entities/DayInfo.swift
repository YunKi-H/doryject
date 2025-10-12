//
//  DayInfo.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import Foundation

struct DayInfo: Identifiable {
    let id: UUID = .init()
    let date: Date
    var rangeEvents: [DayEvent] = []
    var singleEvents: [DayEvent] = []
    var isToday: Bool = false
    var isCurrentMonth: Bool = false
}
