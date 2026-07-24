//
//  SettingsChangeRefreshService.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation

protocol SettingsChangeRefreshing {
    func refresh(using settings: UserSettings)
}

final class SettingsChangeRefreshService: SettingsChangeRefreshing {
    private let eventRepository: EventRepository
    private let notificationScheduler: NotificationScheduler
    private let appleCalendarSyncService: AppleCalendarSyncService
    private let widgetReloader: WidgetReloading

    init(
        eventRepository: EventRepository,
        notificationScheduler: NotificationScheduler,
        appleCalendarSyncService: AppleCalendarSyncService,
        widgetReloader: WidgetReloading
    ) {
        self.eventRepository = eventRepository
        self.notificationScheduler = notificationScheduler
        self.appleCalendarSyncService = appleCalendarSyncService
        self.widgetReloader = widgetReloader
    }

    func refresh(using settings: UserSettings) {
        notificationScheduler.apply(
            settings: settings,
            eventRepository: eventRepository
        )
        widgetReloader.reloadAll()
        Task {
            await appleCalendarSyncService.syncAll()
        }
    }
}
