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
