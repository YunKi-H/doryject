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
    private let calendarStateRefresher: () -> Void

    init(
        eventRepository: EventRepository,
        notificationScheduler: NotificationScheduler,
        appleCalendarSyncService: AppleCalendarSyncService,
        widgetReloader: WidgetReloading,
        calendarStateRefresher: @escaping () -> Void = {}
    ) {
        self.eventRepository = eventRepository
        self.notificationScheduler = notificationScheduler
        self.appleCalendarSyncService = appleCalendarSyncService
        self.widgetReloader = widgetReloader
        self.calendarStateRefresher = calendarStateRefresher
    }

    func refresh(using settings: UserSettings) {
        calendarStateRefresher()
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
