//
//  PillReminderNotificationScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import UserNotifications

enum PillReminderNotificationScheduler {
    static let identifiers = (0..<3).map { "notification.pill.reminder.\($0)" }

    static func apply(
        settings: UserSettings,
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        center: UNUserNotificationCenter = .current()
    ) {
        let requests = notificationRequests(
            settings: settings,
            pillDates: pillDates,
            pillCycles: pillCycles,
            now: now,
            calendar: calendar
        )
        removeUnusedRequests(from: requests, center: center)

        for request in requests {
            center.add(request)
        }
    }

    private static func removeUnusedRequests(
        from requests: [UNNotificationRequest],
        center: UNUserNotificationCenter
    ) {
        let activeIdentifiers = Set(requests.map(\.identifier))
        let unusedIdentifiers = identifiers.filter { !activeIdentifiers.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: unusedIdentifiers)
    }

    private static func notificationRequests(
        settings: UserSettings,
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo],
        now: Date,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        guard settings.notifications.pillReminderEnabled,
              let projection = PeriodForecastCalculator.activePillCycleProjection(
                settings: settings,
                pillDates: pillDates,
                pillCycles: pillCycles,
                on: now,
                calendar: calendar
              ) else {
            return []
        }

        let intakeDates = PillReminderScheduleCalculator.upcomingIntakeDates(
            projection: projection,
            from: now,
            count: identifiers.count + 1,
            calendar: calendar
        )

        let reminderDates: [Date] = intakeDates.compactMap { intakeDate -> Date? in
            guard let scheduledDate = Self.reminderDate(
                on: intakeDate,
                time: settings.notifications.pillReminderTime,
                calendar: calendar
            ),
                  scheduledDate > now else {
                return nil
            }

            return scheduledDate
        }

        return reminderDates.prefix(identifiers.count).enumerated().map { index, reminderDate in
            notificationRequest(
                identifier: identifiers[index],
                date: reminderDate,
                calendar: calendar
            )
        }
    }

    private static func notificationRequest(
        identifier: String,
        date: Date,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "B-Day"
        content.body = "피임약을 복용하실 시간입니다."
        content.sound = .default

        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }

    private static func reminderDate(
        on date: Date,
        time: DateComponents,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }
}
