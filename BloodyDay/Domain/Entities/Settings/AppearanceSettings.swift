//
//  AppearanceSettings.swift
//  BloodyDay
//
//  Created by Yunki on 4/13/26.
//

import Foundation

struct AppearanceSettings: Codable {
    var mode: AppAppearance = .system

    init(mode: AppAppearance = .system) {
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
        case mode
    }

    init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(
            AppAppearance.self,
            forKey: .mode,
            default: defaults.mode
        )
    }
}

enum AppAppearance: String, Codable, CaseIterable {
    case system
    case light
    case dark
}
