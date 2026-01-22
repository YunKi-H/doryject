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
}
