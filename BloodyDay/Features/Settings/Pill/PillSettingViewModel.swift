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
        update(&settings.pill)
        repo.save(settings)
    }
}
