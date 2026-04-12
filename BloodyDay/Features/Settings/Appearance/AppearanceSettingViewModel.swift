//
//  AppearanceSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 4/12/26.
//

import Foundation
import Observation

@Observable
final class AppearanceSettingViewModel {
    private let repo: SettingsRepository
    private(set) var settings: UserSettings
    
    init(repo: SettingsRepository) {
        self.repo = repo
        self.settings = repo.load()
    }
    
    var selectedAppearance: AppAppearance {
        settings.appearance.mode
    }
    
    func select(_ appearance: AppAppearance) {
        var latest = repo.load()
        latest.appearance.mode = appearance
        settings = latest
        repo.save(latest)
    }
    
    func reload() {
        settings = repo.load()
    }
}
