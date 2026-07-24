//
//  PillSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation
import Observation

@Observable
final class PillSettingsViewModel {
    private let repo: SettingsRepository
    private let settingsChangeRefresher: SettingsChangeRefreshing?
    private(set) var settings: UserSettings
    
    init(
        repo: SettingsRepository,
        settingsChangeRefresher: SettingsChangeRefreshing? = nil
    ) {
        self.repo = repo
        self.settingsChangeRefresher = settingsChangeRefresher
        self.settings = repo.load()
    }
    
    func updatePill(_ update: (inout PillSettings) -> Void) {
        settings = repo.update {
            update(&$0.pill)
        }
        settingsChangeRefresher?.refresh(using: settings)
    }

    func reload() {
        settings = repo.load()
    }
}
