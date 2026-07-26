//
//  PillCycleInfo.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation

enum PillCycleStatus: String, Codable, Sendable {
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

    func startDate(calendar: Calendar) -> Date? {
        intakeDates.map { calendar.startOfDay(for: $0) }.min()
    }

    func lastIntakeDate(calendar: Calendar) -> Date? {
        intakeDates.map { calendar.startOfDay(for: $0) }.max()
    }
}
