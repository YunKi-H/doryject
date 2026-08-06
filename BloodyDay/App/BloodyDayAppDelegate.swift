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
            await clearApplicationBadge(source: "didFinishLaunching")
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
        Task { @MainActor in
            await clearApplicationBadge(source: "didBecomeActive")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (
            UNNotificationPresentationOptions
        ) -> Void
    ) {
        completionHandler([.banner, .sound])
        Task { @MainActor in
            await clearApplicationBadge(
                using: center,
                source: "willPresentNotification"
            )
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let route = AppPushNotificationRoute(
            userInfo: response.notification.request.content.userInfo
        ) else {
            completionHandler()
            return
        }
        completionHandler()
        Task { @MainActor in
            AppPushNotificationRouter.shared.receive(route)
        }
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

    @MainActor
    private func clearApplicationBadge(
        using center: UNUserNotificationCenter = .current(),
        source: String
    ) async {
        #if DEBUG
        print("[PushNotification] badge reset started source=" + source)
        #endif

        do {
            try await center.setBadgeCount(0)
            #if DEBUG
            print("[PushNotification] badge reset completed source=" + source)
            #endif
        } catch {
            #if DEBUG
            print(
                "[PushNotification] badge reset failed source="
                    + source
                    + " error="
                    + error.localizedDescription
            )
            #endif
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
