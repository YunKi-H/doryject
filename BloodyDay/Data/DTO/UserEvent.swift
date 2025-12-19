//
//  UserEvent.swift
//  BloodyDay
//
//  Created by Yunki on 10/21/25.
//

import Foundation
import SwiftData

@Model
final class UserEvent {
    var id: UUID
    var date: Date
    var type: EventType
    
    @Attribute(.unique)
    var uniqueKey: String
    
    init(id: UUID = .init(), date: Date, type: EventType, calendar: Calendar = .current) {
        self.id = id
        self.date = date
        self.type = type
        self.uniqueKey = Self.makeUniqueKey(date: date, type: type, calendar: calendar)
    }
    
    static func makeUniqueKey(date: Date, type: EventType, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let dayKey = (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
        return "\(dayKey)|\(type.rawValue)"
    }
}
