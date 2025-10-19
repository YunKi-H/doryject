//
//  DayInfo.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import Foundation

struct DayInfo: Identifiable, Equatable, Hashable {
    static func == (lhs: DayInfo, rhs: DayInfo) -> Bool { lhs.id == rhs.id }
    
    let id: UUID = .init()
    let date: Date
    var events: [DayEvent] = []
}
