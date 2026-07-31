//
//  NotificationSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct NotificationSettings: Codable {
    var periodReminderEnabled: Bool = true
    var periodReminderDaysBefore: Int = 2
    var periodReminderTime: DateComponents = .init(hour: 9, minute: 0)
    var periodDelayedEnabled: Bool = false
    var pillReminderEnabled: Bool = false
    var pillReminderTime: DateComponents = .init(hour: 9, minute: 0)
    var pillPurchaseReminderEnabled: Bool = false
    var pillPurchaseReminderDaysBefore: Int = 1
    var pillPurchaseReminderTime: DateComponents = .init(hour: 16, minute: 0)

    init(
        periodReminderEnabled: Bool = true,
        periodReminderDaysBefore: Int = 2,
        periodReminderTime: DateComponents = .init(hour: 9, minute: 0),
        periodDelayedEnabled: Bool = false,
        pillReminderEnabled: Bool = false,
        pillReminderTime: DateComponents = .init(hour: 9, minute: 0),
        pillPurchaseReminderEnabled: Bool = false,
        pillPurchaseReminderDaysBefore: Int = 1,
        pillPurchaseReminderTime: DateComponents = .init(hour: 16, minute: 0)
    ) {
        self.periodReminderEnabled = periodReminderEnabled
        self.periodReminderDaysBefore = periodReminderDaysBefore
        self.periodReminderTime = periodReminderTime
        self.periodDelayedEnabled = periodDelayedEnabled
        self.pillReminderEnabled = pillReminderEnabled
        self.pillReminderTime = pillReminderTime
        self.pillPurchaseReminderEnabled = pillPurchaseReminderEnabled
        self.pillPurchaseReminderDaysBefore = pillPurchaseReminderDaysBefore
        self.pillPurchaseReminderTime = pillPurchaseReminderTime
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case periodReminderEnabled
        case periodReminderDaysBefore
        case periodReminderTime
        case periodDelayedEnabled
        case pillReminderEnabled
        case pillReminderTime
        case pillPurchaseReminderEnabled
        case pillPurchaseReminderDaysBefore
        case pillPurchaseReminderTime
    }

    init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        periodReminderEnabled = try container.decode(Bool.self, forKey: .periodReminderEnabled, default: defaults.periodReminderEnabled)
        periodReminderDaysBefore = try container.decode(Int.self, forKey: .periodReminderDaysBefore, default: defaults.periodReminderDaysBefore)
        periodReminderTime = try container.decode(DateComponents.self, forKey: .periodReminderTime, default: defaults.periodReminderTime)
        periodDelayedEnabled = try container.decode(Bool.self, forKey: .periodDelayedEnabled, default: defaults.periodDelayedEnabled)
        pillReminderEnabled = try container.decode(Bool.self, forKey: .pillReminderEnabled, default: defaults.pillReminderEnabled)
        pillReminderTime = try container.decode(DateComponents.self, forKey: .pillReminderTime, default: defaults.pillReminderTime)
        pillPurchaseReminderEnabled = try container.decode(Bool.self, forKey: .pillPurchaseReminderEnabled, default: defaults.pillPurchaseReminderEnabled)
        pillPurchaseReminderDaysBefore = try container.decode(Int.self, forKey: .pillPurchaseReminderDaysBefore, default: defaults.pillPurchaseReminderDaysBefore)
        pillPurchaseReminderTime = try container.decode(DateComponents.self, forKey: .pillPurchaseReminderTime, default: defaults.pillPurchaseReminderTime)
    }
}
