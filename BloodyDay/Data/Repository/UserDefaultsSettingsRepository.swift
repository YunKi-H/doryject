//
//  UserDefaultsSettingsRepository.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

final class UserDefaultsSettingsRepository: SettingsRepository {
    private let key = "user.settings.v1"
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func load() -> UserSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return settings
    }
    
    func save(_ settings: UserSettings) {
        let data = try? JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}
