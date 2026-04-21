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
    var appearance: AppearanceSettings = .init()
    var calendarScope: CalendarScopeSettings = .init()
    var calendarSharing: CalendarSharingSettings = .init()
    
    init(
        period: PeriodSettings = .init(),
        pill: PillSettings = .init(),
        notifications: NotificationSettings = .init(),
        appleCalendar: AppleCalendarSettings = .init(),
        appearance: AppearanceSettings = .init(),
        calendarScope: CalendarScopeSettings = .init(),
        calendarSharing: CalendarSharingSettings = .init()
    ) {
        self.period = period
        self.pill = pill
        self.notifications = notifications
        self.appleCalendar = appleCalendar
        self.appearance = appearance
        self.calendarScope = calendarScope
        self.calendarSharing = calendarSharing
    }
    
    private enum CodingKeys: String, CodingKey {
        case period
        case pill
        case notifications
        case appleCalendar
        case appearance
        case calendarScope
        case calendarSharing
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decodeIfPresent(PeriodSettings.self, forKey: .period) ?? .init()
        pill = try container.decodeIfPresent(PillSettings.self, forKey: .pill) ?? .init()
        notifications = try container.decodeIfPresent(NotificationSettings.self, forKey: .notifications) ?? .init()
        appleCalendar = try container.decodeIfPresent(AppleCalendarSettings.self, forKey: .appleCalendar) ?? .init()
        appearance = try container.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? .init()
        calendarScope = try container.decodeIfPresent(CalendarScopeSettings.self, forKey: .calendarScope) ?? .init()
        calendarSharing = try container.decodeIfPresent(CalendarSharingSettings.self, forKey: .calendarSharing) ?? .init()
    }
}
