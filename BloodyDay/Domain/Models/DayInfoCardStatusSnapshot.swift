//
//  DayInfoCardStatusSnapshot.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

enum DayInfoCardPrimarySnapshot: Equatable {
    case countdown(days: Int)
    case ongoing(day: Int)
    case bDay
    case delayed(days: Int)
    case unknown
}

enum DayInfoCardSecondarySnapshot: Equatable {
    case pill(day: Int, total: Int?)
    case pillBreak(day: Int, total: Int)
    case ovulation
    case fertile
    case notFertile
    case unknown
}
