//
//  BloodyDayAppDelegate.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class BloodyDayAppDelegate: NSObject,
                                  UIApplicationDelegate,
                                  MessagingDelegate,
                                  UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        FirebaseAuthSharedAccess.configureAndMigrateCurrentUser()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        Task { @MainActor in
            await PushDeviceRegistrationService.shared
                .synchronizeIfAuthenticated()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        Task { @MainActor in
            await PushDeviceRegistrationService.shared.refreshRegistration()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print(
            "[PushDeviceRegistration] APNs registration failed: "
                + error.localizedDescription
        )
        #endif
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let route = AppPushNotificationRoute(
            userInfo: response.notification.request.content.userInfo
        ) else {
            return
        }
        await AppPushNotificationRouter.shared.receive(route)
    }

    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        Task { @MainActor in
            await PushDeviceRegistrationService.shared
                .updateFCMToken(fcmToken)
        }
    }
}
