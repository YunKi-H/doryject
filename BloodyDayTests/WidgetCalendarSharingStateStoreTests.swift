//
//  WidgetCalendarSharingStateStoreTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct WidgetCalendarSharingStateStoreTests {
    @Test
    func savesRoleAndClearsPendingSyncTogether() throws {
        let suiteName =
            "WidgetCalendarSharingStateStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = WidgetCalendarSharingStateStore(defaults: defaults)
        let state = WidgetCalendarSharingState(
            role: .owner,
            connectionID: "connection"
        )

        store.save(state)
        store.setPendingSync(true)

        #expect(store.load() == state)
        #expect(store.hasPendingSync)

        store.clear()

        #expect(store.load() == nil)
        #expect(store.hasPendingSync == false)
    }
}
