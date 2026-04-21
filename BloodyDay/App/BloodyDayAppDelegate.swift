//
//  BloodyDayAppDelegate.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import CloudKit
import UIKit

final class BloodyDayAppDelegate: NSObject, UIApplicationDelegate {
    static let didAcceptShareNotification = Notification.Name("BloodyDayAppDelegate.didAcceptShare")
    
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        NotificationCenter.default.post(
            name: Self.didAcceptShareNotification,
            object: nil,
            userInfo: ["metadata": cloudKitShareMetadata]
        )
    }
}
