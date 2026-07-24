//
//  PillCycleRecord.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import SwiftData

@Model
final class PillCycle {
    var id: UUID
    var startDate: Date
    var plannedPillCount: Int?
    var breakDays: Int?
    var autoRecordEnabled: Bool?
    var statusRaw: String

    var status: PillCycleStatus {
        get { PillCycleStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = .init(),
        startDate: Date,
        plannedPillCount: Int?,
        breakDays: Int?,
        autoRecordEnabled: Bool?,
        status: PillCycleStatus
    ) {
        self.id = id
        self.startDate = startDate.startOfDay
        self.plannedPillCount = plannedPillCount
        self.breakDays = breakDays
        self.autoRecordEnabled = autoRecordEnabled
        self.statusRaw = status.rawValue
    }
}
