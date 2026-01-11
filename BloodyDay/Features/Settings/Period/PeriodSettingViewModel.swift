//
//  PeriodSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation
import Observation

@Observable
final class PeriodSettingViewModel {
    private let repo: SettingsRepository
    private(set) var settings: UserSettings
    
    init(repo: SettingsRepository) {
        self.repo = repo
        self.settings = repo.load()
    }
    
    func setAutoPrediction(_ enabled: Bool) {
        settings.period.autoCyclePredictionEnabled = enabled
        repo.save(settings)
    }
    
    func updateAverages(cycle: Int?, period: Int?) {
        settings.period.averageCycleDays = cycle
        settings.period.averagePeriodDays = period
        repo.save(settings)
    }
}
