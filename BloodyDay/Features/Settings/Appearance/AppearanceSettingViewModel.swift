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
        settings = repo.update {
            $0.appearance.mode = appearance
        }
    }
    
    func reload() {
        settings = repo.load()
    }
}
