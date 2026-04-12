//
//  SettingsRepository.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

protocol SettingsRepository {
    func load() -> UserSettings
    func save(_ settings: UserSettings)
}

extension SettingsRepository {
    @discardableResult
    func update(_ mutate: (inout UserSettings) -> Void) -> UserSettings {
        var settings = load()
        mutate(&settings)
        save(settings)
        return settings
    }
}
