//
//  CalendarScopeNotificationScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 8/15/26.
//

import Foundation

final class CalendarScopeNotificationScheduler: NotificationScheduler {
    private let base: NotificationScheduler
    private let lock = NSLock()
    private var isSharedCalendarActive = false

    init(base: NotificationScheduler) {
        self.base = base
    }

    func setSharedCalendarActive(_ isActive: Bool) {
        lock.withLock {
            isSharedCalendarActive = isActive
        }
    }

    func apply(
        settings: UserSettings,
        eventRepository: EventRepository
    ) {
        let isSharedCalendarActive = lock.withLock {
            self.isSharedCalendarActive
        }
        var effectiveSettings = settings
        if isSharedCalendarActive {
            effectiveSettings.notifications = settings.notifications
                .disablingAll()
        }
        base.apply(
            settings: effectiveSettings,
            eventRepository: eventRepository
        )
    }
}
