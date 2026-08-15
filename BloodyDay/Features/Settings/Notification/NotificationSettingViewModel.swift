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
    private(set) var isSharedCalendarActive = false
    
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
        guard isSharedCalendarActive == false else { return }
        settings = repo.update {
            update(&$0.notifications)
        }
        scheduler.apply(settings: settings, eventRepository: eventRepository)
    }

    var displayedNotifications: NotificationSettings {
        guard isSharedCalendarActive else {
            return settings.notifications
        }
        return settings.notifications.disablingAll()
    }

    func setSharedCalendarActive(_ isActive: Bool) {
        guard isSharedCalendarActive != isActive else { return }
        isSharedCalendarActive = isActive
        refreshSchedules()
    }
    
    func refreshSchedules() {
        settings = repo.load()
        scheduler.apply(settings: settings, eventRepository: eventRepository)
    }
}
