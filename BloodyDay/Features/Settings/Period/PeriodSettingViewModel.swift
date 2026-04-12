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
        settings = repo.update {
            $0.period.autoCyclePredictionEnabled = enabled
        }
    }
    
    func updateAverages(cycle: Int?, period: Int?) {
        settings = repo.update {
            $0.period.averageCycleDays = cycle
            $0.period.averagePeriodDays = period
        }
    }
    
    func resetAllEvents() {
        guard let eventRepository else { return }
        let events = eventRepository.allEvents()
        for event in events {
            eventRepository.delete(id: event.id)
        }
    }
}
