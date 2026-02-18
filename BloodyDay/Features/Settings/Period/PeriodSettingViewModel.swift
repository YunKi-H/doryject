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
    private let eventRepository: EventRepository?
    private(set) var settings: UserSettings
    
    init(repo: SettingsRepository, eventRepository: EventRepository? = nil) {
        self.repo = repo
        self.eventRepository = eventRepository
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
    
    func resetAllEvents() {
        guard let eventRepository else { return }
        let events = eventRepository.allEvents()
        for event in events {
            eventRepository.delete(id: event.id)
        }
    }
}
