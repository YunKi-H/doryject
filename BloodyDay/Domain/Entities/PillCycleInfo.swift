//
//  PillCycleInfo.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation

enum PillCycleStatus: String, Codable {
    case active
    case completed
}

struct PillCycleInfo: Equatable {
    let id: UUID
    let intakeDates: [Date]
    let plannedPillCount: Int?
    let breakDays: Int?
    let autoRecordEnabled: Bool?
    let status: PillCycleStatus

    var startDate: Date? {
        intakeDates.map(\.startOfDay).min()
    }

    var lastIntakeDate: Date? {
        intakeDates.map(\.startOfDay).max()
    }
}
