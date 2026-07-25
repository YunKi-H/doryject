//
//  BloodyDayAppDelegate.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import FirebaseCore
import UIKit

final class BloodyDayAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}
