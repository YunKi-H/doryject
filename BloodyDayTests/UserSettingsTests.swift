//
//  UserSettingsTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/13/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct UserSettingsTests {
    @Test
    func decodingEmptySettingsUsesAllDefaults() throws {
        let settings = try JSONDecoder().decode(
            UserSettings.self,
            from: Data("{}".utf8)
        )

        #expect(settings.period == PeriodSettings())
        #expect(settings.pill == PillSettings())
        #expect(settings.notifications.periodReminderEnabled)
        #expect(settings.notifications.periodReminderDaysBefore == 2)
        #expect(
            settings.appleCalendar.eventSyncEnabled
                == AppleCalendarSettings.defaultEventSyncEnabled
        )
        #expect(settings.appearance.mode == .system)
    }

    @Test
    func decodingLegacySettingsWithoutAppearancePreservesPillSettings() throws {
        var original = UserSettings()
        original.pill.pillEnabled = true
        original.pill.pillAutoRecordEnabled = true
        original.pill.pillCount = 21
        original.pill.pillBreakDuration = 7
        
        var legacyPayload = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(original)
        ) as? [String: Any]
        legacyPayload?["appearance"] = nil
        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload ?? [:])
        
        let settings = try JSONDecoder().decode(UserSettings.self, from: legacyData)
        
        #expect(settings.pill.pillEnabled == true)
        #expect(settings.pill.pillAutoRecordEnabled == true)
        #expect(settings.pill.pillCount == 21)
        #expect(settings.pill.pillBreakDuration == 7)
        #expect(settings.appearance.mode == .system)
    }

    @Test
    func decodingPartialChildSettingsUsesEachModelsDefaults() throws {
        let data = Data(
            """
            {
              "period": { "averageCycleDays": 30 },
              "pill": { "pillEnabled": true },
              "notifications": { "pillReminderEnabled": true },
              "appleCalendar": { "isEnabled": true },
              "appearance": {}
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(UserSettings.self, from: data)

        #expect(settings.period.averageCycleDays == 30)
        #expect(settings.period.autoCyclePredictionEnabled)
        #expect(settings.period.averagePeriodDays == nil)
        #expect(settings.pill.pillEnabled)
        #expect(settings.pill.pillCount == 21)
        #expect(settings.pill.pillBreakDuration == 7)
        #expect(settings.notifications.pillReminderEnabled)
        #expect(settings.notifications.periodReminderEnabled)
        #expect(settings.notifications.periodReminderDaysBefore == 2)
        #expect(settings.appleCalendar.isEnabled)
        #expect(
            settings.appleCalendar.eventSyncEnabled
                == AppleCalendarSettings.defaultEventSyncEnabled
        )
        #expect(
            settings.appleCalendar.calendarNames
                == AppleCalendarSettings.defaultCalendarNames
        )
        #expect(settings.appearance.mode == .system)
    }
}
