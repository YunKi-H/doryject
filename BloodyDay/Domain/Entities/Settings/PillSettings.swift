//
//  PillSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct PillSettings: Codable, Equatable, Sendable {
    var pillEnabled: Bool = false
    var pillTime: DateComponents = .init(hour: 9, minute: 0)
    var pillAutoRecordEnabled: Bool = false
    var pillCount: Int = 21
    var pillBreakDuration: Int = 7

    private enum CodingKeys: String, CodingKey {
        case pillEnabled
        case pillTime
        case pillAutoRecordEnabled
        case pillCount
        case pillBreakDuration
    }

    init(
        pillEnabled: Bool = false,
        pillTime: DateComponents = .init(hour: 9, minute: 0),
        pillAutoRecordEnabled: Bool = false,
        pillCount: Int = 21,
        pillBreakDuration: Int = 7
    ) {
        self.pillEnabled = pillEnabled
        self.pillTime = pillTime
        self.pillAutoRecordEnabled = pillAutoRecordEnabled
        self.pillCount = pillCount
        self.pillBreakDuration = pillBreakDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        pillEnabled = try container.decode(Bool.self, forKey: .pillEnabled, default: defaults.pillEnabled)
        pillTime = try container.decode(DateComponents.self, forKey: .pillTime, default: defaults.pillTime)
        pillAutoRecordEnabled = try container.decode(Bool.self, forKey: .pillAutoRecordEnabled, default: defaults.pillAutoRecordEnabled)
        pillCount = try container.decode(Int.self, forKey: .pillCount, default: defaults.pillCount)
        pillBreakDuration = try container.decode(Int.self, forKey: .pillBreakDuration, default: defaults.pillBreakDuration)
    }
}
