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
                let body = periodReminderBody(daysBefore: daysBefore)
                scheduleOnce(
                    identifier: Self.periodReminderIds[index],
                    title: "B-Day",
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
                    let daysDelayed = max(
                        calendar.dateComponents([.day], from: nextPeriodStart.startOfDay, to: date.startOfDay).day ?? 0,
                        0
                    )
                    scheduleOnce(
                        identifier: Self.periodDelayedIds[index],
                        title: "B-Day",
                        body: periodDelayedBody(daysDelayed: daysDelayed),
                        date: date
                    )
                }
            }
        }
        if notificationSettings.pillReminderEnabled, settings.pill.pillEnabled {
            scheduleDaily(
                identifier: Self.pillReminderId,
                title: "B-Day",
                body: "피임약을 복용하실 시간입니다.",
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
                    title: "B-Day",
                    body: pillPurchaseReminderBody(daysBefore: max(notificationSettings.pillPurchaseReminderDaysBefore, 0)),
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

    private func periodReminderBody(daysBefore: Int) -> String {
        switch daysBefore {
        case 1:
            return "생리 예정일 하루 전입니다."
        case 0:
            return "오늘은 생리 예정일 입니다."
        default:
            return "생리 예정일이 \(daysBefore)일 남았습니다."
        }
    }

    private func pillPurchaseReminderBody(daysBefore: Int) -> String {
        switch daysBefore {
        case 1:
            return "내일부터 새로운 피임약 복용이 시작됩니다. 미리 준비해주세요."
        case 0:
            return "오늘부터 새로운 피임약 복용이 시작됩니다. 잊지 말고 복용해주세요."
        default:
            return "\(daysBefore)일 후부터 새로운 피임약 복용이 시작됩니다. 미리 준비해주세요."
        }
    }

    private func periodDelayedBody(daysDelayed: Int) -> String {
        if daysDelayed >= 7 {
            return "생리가 7일 이상 지연되고 있습니다. 개인 건강을 위해 병원 진료를 권장합니다."
        }
        return "생리가 예정일보다 \(daysDelayed)일 지연되고 있습니다. 스트레스나 컨디션을 점검해보세요."
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
