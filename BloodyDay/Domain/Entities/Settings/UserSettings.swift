//
//  UserSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

extension KeyedDecodingContainer {
    func decode<T: Decodable>(
        _ type: T.Type,
        forKey key: Key,
        default defaultValue: @autoclosure () -> T
    ) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? defaultValue()
    }
}

struct UserSettings: Codable {
    var period: PeriodSettings = .init()
    var pill: PillSettings = .init()
    var notifications: NotificationSettings = .init()
    var appleCalendar: AppleCalendarSettings = .init()
    var appearance: AppearanceSettings = .init()
    
    init(
        period: PeriodSettings = .init(),
        pill: PillSettings = .init(),
        notifications: NotificationSettings = .init(),
        appleCalendar: AppleCalendarSettings = .init(),
        appearance: AppearanceSettings = .init()
    ) {
        self.period = period
        self.pill = pill
        self.notifications = notifications
        self.appleCalendar = appleCalendar
        self.appearance = appearance
    }
    
    private enum CodingKeys: String, CodingKey {
        case period
        case pill
        case notifications
        case appleCalendar
        case appearance
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(PeriodSettings.self, forKey: .period, default: .init())
        pill = try container.decode(PillSettings.self, forKey: .pill, default: .init())
        notifications = try container.decode(NotificationSettings.self, forKey: .notifications, default: .init())
        appleCalendar = try container.decode(AppleCalendarSettings.self, forKey: .appleCalendar, default: .init())
        appearance = try container.decode(AppearanceSettings.self, forKey: .appearance, default: .init())
    }
}
