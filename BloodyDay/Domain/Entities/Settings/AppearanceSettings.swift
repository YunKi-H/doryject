//
//  AppearanceSettings.swift
//  BloodyDay
//
//  Created by Yunki on 4/13/26.
//

import Foundation

struct AppearanceSettings: Codable {
    var mode: AppAppearance = .system
}

enum AppAppearance: String, Codable, CaseIterable {
    case system
    case light
    case dark
}
