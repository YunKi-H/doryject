//
//  SharedEventTypeSelection.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

struct SharedEventTypeSelection: Codable, Equatable, Hashable {
    var period: Bool = false
    var pill: Bool = false
    var love: Bool = false
    
    static let none = SharedEventTypeSelection()
    static let all = SharedEventTypeSelection(period: true, pill: true, love: true)
    
    var eventTypes: Set<EventType> {
        var types: Set<EventType> = []
        if period { types.insert(.period) }
        if pill { types.insert(.pill) }
        if love { types.insert(.love) }
        return types
    }
    
    func contains(_ type: EventType) -> Bool {
        switch type {
        case .period:
            return period
        case .pill:
            return pill
        case .love:
            return love
        case .ovulation, .fertile, .delayed:
            return false
        }
    }
    
    mutating func set(_ type: EventType, enabled: Bool) {
        switch type {
        case .period:
            period = enabled
        case .pill:
            pill = enabled
        case .love:
            love = enabled
        case .ovulation, .fertile, .delayed:
            break
        }
    }
}
