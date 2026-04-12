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
        let json = """
        {
          "period": {
            "autoCyclePredictionEnabled": true
          },
          "pill": {
            "pillEnabled": true,
            "pillAutoRecordEnabled": true,
            "pillCount": 21,
            "pillBreakDuration": 7
          },
          "notifications": {},
          "appleCalendar": {}
        }
        """
        
        let settings = try JSONDecoder().decode(UserSettings.self, from: Data(json.utf8))
        
        #expect(settings.pill.pillEnabled == true)
        #expect(settings.pill.pillAutoRecordEnabled == true)
        #expect(settings.pill.pillCount == 21)
        #expect(settings.pill.pillBreakDuration == 7)
        #expect(settings.appearance.mode == .system)
    }
}
