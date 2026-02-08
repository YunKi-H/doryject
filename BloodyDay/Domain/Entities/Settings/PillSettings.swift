//
//  PillSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct PillSettings: Codable {
    var pillTime: DateComponents = .init(hour: 9, minute: 0)
    var pillAutoRecordEnabled: Bool = false
    var pillCount: Int = 21
    var pillBreakDuration: Int = 7
}
