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
    func decodingLegacySettingsWithoutNewSectionsPreservesPillSettings() throws {
        var original = UserSettings()
        original.pill.pillEnabled = true
        original.pill.pillAutoRecordEnabled = true
        original.pill.pillCount = 21
        original.pill.pillBreakDuration = 7
        
        var legacyPayload = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(original)
        ) as? [String: Any]
        legacyPayload?["appearance"] = nil
        legacyPayload?["calendarScope"] = nil
        legacyPayload?["calendarSharing"] = nil
        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload ?? [:])
        
        let settings = try JSONDecoder().decode(UserSettings.self, from: legacyData)
        
        #expect(settings.pill.pillEnabled == true)
        #expect(settings.pill.pillAutoRecordEnabled == true)
        #expect(settings.pill.pillCount == 21)
        #expect(settings.pill.pillBreakDuration == 7)
        #expect(settings.appearance.mode == .system)
        #expect(settings.calendarScope.selectedScope == .mine)
        #expect(settings.calendarSharing.defaultSharedEventTypes == .all)
    }
    
    @Test
    func decodingCalendarSharingSettingsPreservesDefaultSharedEventTypes() throws {
        var original = UserSettings()
        original.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(
            period: true,
            pill: false,
            love: true
        )
        
        let data = try JSONEncoder().encode(original)
        let settings = try JSONDecoder().decode(UserSettings.self, from: data)
        
        #expect(settings.calendarSharing.defaultSharedEventTypes.period == true)
        #expect(settings.calendarSharing.defaultSharedEventTypes.pill == false)
        #expect(settings.calendarSharing.defaultSharedEventTypes.love == true)
    }
}
