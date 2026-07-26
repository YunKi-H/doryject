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

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pillEnabled = try container.decodeIfPresent(Bool.self, forKey: .pillEnabled) ?? false
        pillTime = try container.decodeIfPresent(DateComponents.self, forKey: .pillTime) ?? .init(hour: 9, minute: 0)
        pillAutoRecordEnabled = try container.decodeIfPresent(Bool.self, forKey: .pillAutoRecordEnabled) ?? false
        pillCount = try container.decodeIfPresent(Int.self, forKey: .pillCount) ?? 21
        pillBreakDuration = try container.decodeIfPresent(Int.self, forKey: .pillBreakDuration) ?? 7
    }
}
