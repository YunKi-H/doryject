//
//  AppleCalendarEventSyncPolicyTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Testing
@testable import BloodyDay

struct AppleCalendarEventSyncPolicyTests {
    @Test
    func periodAndPillRequireFullSyncBecauseTheyAffectForecasts() {
        #expect(AppleCalendarEventSyncPolicy.requiresFullSync(for: .period))
        #expect(AppleCalendarEventSyncPolicy.requiresFullSync(for: .pill))
    }

    @Test
    func loveUsesIncrementalSync() {
        #expect(AppleCalendarEventSyncPolicy.requiresFullSync(for: .love) == false)
    }
}
