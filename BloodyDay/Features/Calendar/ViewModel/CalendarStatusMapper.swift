//
//  CalendarStatusMapper.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

enum CalendarStatusMapper {
    static func map(_ snapshot: DayInfoCardPrimarySnapshot) -> CalendarPrimaryStatus {
        switch snapshot {
        case .countdown(let days):
            return .countdown(days: days)
        case .ongoing(let day):
            return .ongoing(day: day)
        case .bDay:
            return .bDay
        case .delayed(let days):
            return .delayed(days: days)
        case .unknown:
            return .unknown
        }
    }
    
    static func map(_ snapshot: DayInfoCardSecondarySnapshot) -> CalendarSecondaryStatus {
        switch snapshot {
        case .pill(let day, let total):
            return .pill(day: day, total: total)
        case .pillBreak(let day, let total):
            return .pillBreak(day: day, total: total)
        case .ovulation:
            return .ovulation
        case .fertile:
            return .fertile
        case .notFertile:
            return .notFertile
        case .unknown:
            return .unknown
        }
    }
}
