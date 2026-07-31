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
        let retryStore = SharedCalendarSyncRetryStore(
            defaults: defaults
        )
        let state = WidgetCalendarSharingState(
            role: .owner,
            connectionID: "connection"
        )

        store.save(state)
        retryStore.markPending()

        #expect(store.load() == state)
        #expect(retryStore.state?.isPending == true)

        store.clear()

        #expect(store.load() == nil)
        #expect(retryStore.state == nil)
    }

    @Test
    func runtimeStorePersistsCommittedPublicationVersion() throws {
        let suiteName =
            "CalendarSharingRuntimeStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = CalendarSharingRuntimeStore(defaults: defaults)
        let state = CalendarSharingRuntimeState(
            viewerConnectionID: "connection",
            events: [],
            computationSettings: nil,
            publicationVersion: "version-2"
        )

        store.save(state)

        #expect(store.load()?.publicationVersion == "version-2")
    }

    @Test
    func legacyRuntimeStateDefaultsPublicationVersionToNil() throws {
        let data = Data(
            """
            {
              "viewerConnectionID": "connection",
              "events": [],
              "pillCycles": []
            }
            """.utf8
        )

        let state = try JSONDecoder().decode(
            CalendarSharingRuntimeState.self,
            from: data
        )

        #expect(state.publicationVersion == nil)
    }
}
