//
//  NoopNotificationScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

final class NoopNotificationScheduler: NotificationScheduler {
    func apply(settings: UserSettings, eventRepository: EventRepository) {
        // No-op placeholder for app wiring.
    }
}
