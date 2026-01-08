//
//  UserNotificationScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation
import UserNotifications

final class UserNotificationScheduler: NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    
    func apply(settings: UserSettings) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
        
        let notificationSettings = settings.notifications
        if notificationSettings.periodReminderEnabled {
            let body = "시작 예정일 \(notificationSettings.periodReminderDaysBefore)일 전 알림"
            schedule(
                identifier: Self.periodReminderId,
                title: "생리 예정일",
                body: body,
                time: notificationSettings.periodReminderTime
            )
        }
        if notificationSettings.periodDelayedEnabled {
            schedule(
                identifier: Self.periodDelayedId,
                title: "생리 지연",
                body: "생리 일정이 지연되고 있어요",
                time: notificationSettings.periodReminderTime
            )
        }
        if notificationSettings.pillReminderEnabled {
            schedule(
                identifier: Self.pillReminderId,
                title: "피임약 복용",
                body: "피임약 복용 시간이에요",
                time: notificationSettings.pillReminderTime
            )
        }
        if notificationSettings.pillPurchaseReminderEnabled {
            schedule(
                identifier: Self.pillPurchaseReminderId,
                title: "피임약 구매",
                body: "피임약 구매 예정일이에요",
                time: notificationSettings.pillPurchaseReminderTime
            )
        }
    }
    
    private func schedule(
        identifier: String,
        title: String,
        body: String,
        time: DateComponents
    ) {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
    
    private static let periodReminderId = "notification.period.reminder"
    private static let periodDelayedId = "notification.period.delayed"
    private static let pillReminderId = "notification.pill.reminder"
    private static let pillPurchaseReminderId = "notification.pill.purchase"
    private static let identifiers: [String] = [
        periodReminderId,
        periodDelayedId,
        pillReminderId,
        pillPurchaseReminderId
    ]
}
