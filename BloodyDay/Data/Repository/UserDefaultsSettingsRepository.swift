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
    
    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if let sharedDefaults = UserDefaults(suiteName: SharedAppModelContainer.appGroupIdentifier) {
            self.defaults = sharedDefaults
            migrateLegacyValueIfNeeded(to: sharedDefaults)
        } else {
            self.defaults = .standard
        }
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
    
    private func migrateLegacyValueIfNeeded(to sharedDefaults: UserDefaults) {
        guard sharedDefaults.data(forKey: key) == nil,
              let legacyData = UserDefaults.standard.data(forKey: key) else {
            return
        }
        sharedDefaults.set(legacyData, forKey: key)
        sharedDefaults.synchronize()
        UserDefaults.standard.removeObject(forKey: key)
    }
}
