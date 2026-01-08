//
//  UserSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct UserSettings: Codable {
    var period: PeriodSettings = .init()
    var pill: PillSettings = .init()
    var notifications: NotificationSettings = .init()
    var appleCalendar: AppleCalendarSettings = .init()
}
