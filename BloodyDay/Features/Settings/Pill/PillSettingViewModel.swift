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
    private(set) var settings: UserSettings
    
    init(repo: SettingsRepository) {
        self.repo = repo
        self.settings = repo.load()
    }
    
    func updatePill(_ update: (inout PillSettings) -> Void) {
        var latest = repo.load()
        update(&latest.pill)
        settings = latest
        repo.save(latest)
    }

    func reload() {
        settings = repo.load()
    }
}
