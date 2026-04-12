//
//  NotificationSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation
import Observation

@Observable
final class NotificationSettingsViewModel {
    private let repo: SettingsRepository
    private let scheduler: NotificationScheduler
    private let eventRepository: EventRepository
    private(set) var settings: UserSettings
    
    init(
        repo: SettingsRepository,
        scheduler: NotificationScheduler,
        eventRepository: EventRepository
    ) {
        self.repo = repo
        self.scheduler = scheduler
        self.eventRepository = eventRepository
        self.settings = repo.load()
    }
    
    func updateNotifications(_ update: (inout NotificationSettings) -> Void) {
        var latest = repo.load()
        update(&latest.notifications)
        settings = latest
        repo.save(latest)
        scheduler.apply(settings: latest, eventRepository: eventRepository)
    }
    
    func refreshSchedules() {
        settings = repo.load()
        scheduler.apply(settings: settings, eventRepository: eventRepository)
    }
}
