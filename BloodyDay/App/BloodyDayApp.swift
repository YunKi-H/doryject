//
//  BloodyDayApp.swift
//  BloodyDay
//
//  Created by Yunki on 10/9/25.
//

import SwiftUI
import SwiftData

@main
struct BloodyDayApp: App {
    private let sharedModelContainer = SharedAppModelContainer.make()
    
    var body: some Scene {
        WindowGroup {
            BloodyDayRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
