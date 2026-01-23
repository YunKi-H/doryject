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
    private let calendar = Calendar.current
    private let maxScheduledOccurrences = 3
    
    func apply(settings: UserSettings, eventRepository: EventRepository) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
        
        let notificationSettings = settings.notifications
        if notificationSettings.periodReminderEnabled {
            let daysBefore = max(notificationSettings.periodReminderDaysBefore, 0)
            let starts = nextPeriodStarts(
                settings: settings,
                eventRepository: eventRepository,
                count: maxScheduledOccurrences
            )
            for (index, start) in starts.enumerated() {
                guard index < Self.periodReminderIds.count else { break }
                guard let reminderBase = calendar.date(byAdding: .day, value: -daysBefore, to: start),
                      let reminderDate = combineDate(reminderBase, time: notificationSettings.periodReminderTime),
                      reminderDate > Date() else {
                    continue
                }
                let body = "시작 예정일 \(daysBefore)일 전 알림"
                scheduleOnce(
                    identifier: Self.periodReminderIds[index],
                    title: "생리 예정일",
                    body: body,
                    date: reminderDate
                )
            }
        }
        if notificationSettings.periodDelayedEnabled,
           let nextPeriodStart = nextPeriodStart(settings: settings, eventRepository: eventRepository) {
            let today = Date().startOfDay
            if today > nextPeriodStart.startOfDay {
                let scheduled = nextOccurrences(
                    time: notificationSettings.periodReminderTime,
                    from: Date(),
                    count: maxScheduledOccurrences
                )
                for (index, date) in scheduled.enumerated() {
                    guard index < Self.periodDelayedIds.count else { break }
                    scheduleOnce(
                        identifier: Self.periodDelayedIds[index],
                        title: "생리 지연",
                        body: "생리 일정이 지연되고 있어요",
                        date: date
                    )
                }
            }
        }
        if notificationSettings.pillReminderEnabled, settings.pill.pillEnabled {
            scheduleDaily(
                identifier: Self.pillReminderId,
                title: "피임약 복용",
                body: "피임약 복용 시간이에요",
                time: notificationSettings.pillReminderTime
            )
        }
        if notificationSettings.pillPurchaseReminderEnabled, settings.pill.pillEnabled {
            let nextStarts = nextPillStartDates(
                settings: settings,
                eventRepository: eventRepository,
                count: maxScheduledOccurrences
            )
            let reminders = nextPillPurchaseReminderDates(
                nextStarts: nextStarts,
                daysBefore: max(notificationSettings.pillPurchaseReminderDaysBefore, 0),
                time: notificationSettings.pillPurchaseReminderTime
            )
            for (index, reminder) in reminders.enumerated() {
                guard index < Self.pillPurchaseReminderIds.count else { break }
                scheduleOnce(
                    identifier: Self.pillPurchaseReminderIds[index],
                    title: "피임약 구매",
                    body: "피임약 구매 예정일이에요",
                    date: reminder
                )
            }
        }
    }
    
    private func scheduleDaily(
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

    private func scheduleOnce(
        identifier: String,
        title: String,
        body: String,
        date: Date
    ) {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func combineDate(_ date: Date, time: DateComponents) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    private func nextOccurrence(time: DateComponents, from now: Date) -> Date? {
        guard let today = combineDate(now, time: time) else { return nil }
        if today > now {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }

    private func nextOccurrences(
        time: DateComponents,
        from now: Date,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard var next = nextOccurrence(time: time, from: now) else { return [] }
        var results: [Date] = []
        for _ in 0..<count {
            results.append(next)
            guard let following = calendar.date(byAdding: .day, value: 1, to: next) else { break }
            next = following
        }
        return results
    }

    private func nextPeriodStart(
        settings: UserSettings,
        eventRepository: EventRepository
    ) -> Date? {
        let periodEvents = eventRepository.events(of: .period).map { $0.date }
        let summaries = PeriodSummaryBuilder.build(from: periodEvents)
        guard let last = summaries.last else { return nil }

        let settingsPeriod = settings.period
        let cycleDays: Int?
        if settingsPeriod.autoCyclePredictionEnabled == false,
           let manual = settingsPeriod.averageCycleDays {
            cycleDays = manual
        } else {
            cycleDays = averageCycleDays(from: summaries)
        }
        guard let cycle = cycleDays, cycle > 0 else { return nil }
        return calendar.date(byAdding: .day, value: cycle, to: last.start.startOfDay)
    }

    private func nextPeriodStarts(
        settings: UserSettings,
        eventRepository: EventRepository,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard let first = nextPeriodStart(settings: settings, eventRepository: eventRepository) else { return [] }
        let periodEvents = eventRepository.events(of: .period).map { $0.date }
        let summaries = PeriodSummaryBuilder.build(from: periodEvents)
        guard let cycle = cycleLengthDays(settings: settings, summaries: summaries) else { return [] }

        var results: [Date] = []
        var next = first.startOfDay
        for _ in 0..<count {
            results.append(next)
            guard let following = calendar.date(byAdding: .day, value: cycle, to: next) else { break }
            next = following
        }
        return results
    }

    private func cycleLengthDays(settings: UserSettings, summaries: [PeriodSummary]) -> Int? {
        let settingsPeriod = settings.period
        if settingsPeriod.autoCyclePredictionEnabled == false,
           let manual = settingsPeriod.averageCycleDays,
           manual > 0 {
            return manual
        }
        guard let auto = averageCycleDays(from: summaries), auto > 0 else { return nil }
        return auto
    }

    private func averageCycleDays(from summaries: [PeriodSummary]) -> Int? {
        let cycles = summaries.compactMap(\.cycleDays)
        guard !cycles.isEmpty else { return nil }
        let avg = Double(cycles.reduce(0, +)) / Double(cycles.count)
        return Int(round(avg))
    }

    private func nextPillStartDate(
        settings: UserSettings,
        eventRepository: EventRepository
    ) -> Date? {
        let pillSettings = settings.pill
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }

        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let anchor = mostRecentPillStart(from: pillDates) else { return nil }

        let today = Date().startOfDay
        var nextStart = anchor.startOfDay
        while nextStart <= today {
            guard let candidate = calendar.date(byAdding: .day, value: cycleLength, to: nextStart) else {
                return nil
            }
            nextStart = candidate
        }
        return nextStart
    }

    private func nextPillStartDates(
        settings: UserSettings,
        eventRepository: EventRepository,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard let first = nextPillStartDate(settings: settings, eventRepository: eventRepository) else {
            return []
        }
        let pillSettings = settings.pill
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard cycleLength > 0 else { return [] }

        var results: [Date] = []
        var next = first.startOfDay
        for _ in 0..<count {
            results.append(next)
            guard let following = calendar.date(byAdding: .day, value: cycleLength, to: next) else { break }
            next = following
        }
        return results
    }

    private func nextPillPurchaseReminderDates(
        nextStarts: [Date],
        daysBefore: Int,
        time: DateComponents
    ) -> [Date] {
        let now = Date()
        var reminders: [Date] = []
        for start in nextStarts {
            guard let base = calendar.date(byAdding: .day, value: -daysBefore, to: start.startOfDay),
                  let reminder = combineDate(base, time: time) else {
                continue
            }
            if reminder > now {
                reminders.append(reminder)
            }
        }
        return reminders
    }

    private func mostRecentPillStart(from pillDates: Set<Date>) -> Date? {
        guard !pillDates.isEmpty else { return nil }
        let sorted = pillDates.sorted()
        for date in sorted.reversed() {
            let previous = calendar.date(byAdding: .day, value: -1, to: date.startOfDay)!
            if !pillDates.contains(previous) {
                return date.startOfDay
            }
        }
        return sorted.first?.startOfDay
    }
    
    private static let periodReminderId = "notification.period.reminder"
    private static let periodDelayedId = "notification.period.delayed"
    private static let pillReminderId = "notification.pill.reminder"
    private static let pillPurchaseReminderId = "notification.pill.purchase"
    private static let periodReminderIds = (0..<3).map { "\(periodReminderId).\($0)" }
    private static let periodDelayedIds = (0..<3).map { "\(periodDelayedId).\($0)" }
    private static let pillPurchaseReminderIds = (0..<3).map { "\(pillPurchaseReminderId).\($0)" }
    private static let identifiers: [String] = [
        periodReminderId,
        periodDelayedId,
        pillReminderId,
        pillPurchaseReminderId
    ] + periodReminderIds + periodDelayedIds + pillPurchaseReminderIds
}
