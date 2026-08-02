//
//  AppPushNotificationRouteTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 8/2/26.
//

import Testing
@testable import BloodyDay

struct AppPushNotificationRouteTests {
    @Test
    func calendarSharingRouteParsesFromRoutePayload() {
        let route = AppPushNotificationRoute(
            userInfo: ["route": "calendarSharing"]
        )

        #expect(route == .calendarSharing)
    }

    @Test
    func connectionRequestTypeSupportsLegacyPayloadFallback() {
        let route = AppPushNotificationRoute(
            userInfo: ["type": "calendarConnectionRequest"]
        )

        #expect(route == .calendarSharing)
    }

    @Test
    func unrelatedPayloadDoesNotCreateRoute() {
        let route = AppPushNotificationRoute(
            userInfo: ["route": "calendar"]
        )

        #expect(route == nil)
    }
}
