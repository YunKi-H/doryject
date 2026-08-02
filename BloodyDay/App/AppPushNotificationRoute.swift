//
//  AppPushNotificationRoute.swift
//  BloodyDay
//
//  Created by Yunki on 8/2/26.
//

import Foundation
import Observation

enum AppPushNotificationRoute: Hashable, Sendable {
    case calendarSharing

    init?(userInfo: [AnyHashable: Any]) {
        let route = userInfo["route"] as? String
        let type = userInfo["type"] as? String
        guard route == "calendarSharing"
                || type == "calendarConnectionRequest" else {
            return nil
        }
        self = .calendarSharing
    }
}

@MainActor
@Observable
final class AppPushNotificationRouter {
    static let shared = AppPushNotificationRouter()

    private(set) var pendingRoute: AppPushNotificationRoute?

    private init() {}

    func receive(_ route: AppPushNotificationRoute) {
        pendingRoute = route
    }

    func consume(_ route: AppPushNotificationRoute) {
        guard pendingRoute == route else { return }
        pendingRoute = nil
    }
}
