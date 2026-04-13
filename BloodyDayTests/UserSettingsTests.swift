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
}
