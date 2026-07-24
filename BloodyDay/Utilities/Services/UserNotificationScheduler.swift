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
    private static let maxScheduledOccurrences = 3
    private let maxScheduledOccurrences = UserNotificationScheduler.maxScheduledOccurrences
    
    func apply(settings: UserSettings, eventRepository: EventRepository) {
        apply(
            settings: settings,
            eventReader: eventRepository,
            requestsAuthorization: true
        )
    }

    func applyAndWait(
        settings: UserSettings,
        eventReader: EventReading
    ) async {
        apply(
            settings: settings,
            eventReader: eventReader,
            requestsAuthorization: false
        )
        _ = await center.pendingNotificationRequests()
    }

    private func apply(
        settings: UserSettings,
        eventReader: EventReading,
        requestsAuthorization: Bool
    ) {
        if requestsAuthorization {
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
        let now = Date()
        let today = now.startOfDay
        
        let notificationSettings = settings.notifications
        if notificationSettings.periodReminderEnabled {
            let daysBefore = max(notificationSettings.periodReminderDaysBefore, 0)
            let starts = nextPeriodStarts(
                settings: settings,
                eventReader: eventReader,
                count: maxScheduledOccurrences,
                today: today
            )
            var idIndex = 0
            for start in starts {
                for offset in stride(from: daysBefore, through: 0, by: -1) {
                    guard idIndex < Self.periodReminderIds.count else { break }
                    guard let reminderBase = calendar.date(byAdding: .day, value: -offset, to: start),
                          let reminderDate = combineDate(reminderBase, time: notificationSettings.periodReminderTime),
                          reminderDate > now else {
                        continue
                    }
                    let body = periodReminderBody(daysBefore: offset)
                    scheduleOnce(
                        identifier: Self.periodReminderIds[idIndex],
                        title: "B-Day",
                        body: body,
                        date: reminderDate
                    )
                    idIndex += 1
                }
            }
        }
        if notificationSettings.periodDelayedEnabled,
           let currentExpectedStart = currentDelayedPeriodStart(
            settings: settings,
            eventReader: eventReader,
            today: today
           ) {
            if today > currentExpectedStart.startOfDay {
                let scheduled = nextOccurrences(
                    time: notificationSettings.periodReminderTime,
                    from: now,
                    count: maxScheduledOccurrences
                )
                for (index, date) in scheduled.enumerated() {
                    guard index < Self.periodDelayedIds.count else { break }
                    let daysDelayed = max(
                        calendar.dateComponents([.day], from: currentExpectedStart.startOfDay, to: date.startOfDay).day ?? 0,
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
        let pillDates = Set(eventReader.events(of: .pill).map { $0.date.startOfDay })
        PillReminderNotificationScheduler.apply(
            settings: settings,
            pillDates: pillDates,
            now: now,
            calendar: calendar,
            center: center
        )
        if notificationSettings.pillPurchaseReminderEnabled,
           pillScheduleInfo(settings: settings, eventReader: eventReader) != nil {
            let nextStarts = nextPillStartDates(
                settings: settings,
                eventReader: eventReader,
                count: maxScheduledOccurrences,
                today: today
            )
            let reminders = nextPillPurchaseReminderDates(
                nextStarts: nextStarts,
                daysBefore: max(notificationSettings.pillPurchaseReminderDaysBefore, 0),
                time: notificationSettings.pillPurchaseReminderTime,
                now: now
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
    
    private func nextPeriodStarts(
        settings: UserSettings,
        eventReader: EventReading,
        count: Int,
        today: Date
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard let data = periodPredictionData(
            settings: settings,
            eventReader: eventReader,
            target: today
        ) else {
            return []
        }

        let horizonDays = max(data.context.cycleLength, 1) * max(count + 4, 1)
        guard let horizonEndExclusive = calendar.date(
            byAdding: .day,
            value: horizonDays,
            to: today.startOfDay
        )?.startOfDay else {
            return []
        }

        let validStarts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: today,
            rangeEndExclusive: horizonEndExclusive,
            today: today,
            settings: settings,
            periodSummaries: data.summaries,
            pillDates: data.pillDates,
            calendar: calendar
        )
        return Array(validStarts.filter { $0 >= today }.prefix(count))
    }
    
    private func currentDelayedPeriodStart(
        settings: UserSettings,
        eventReader: EventReading,
        today: Date
    ) -> Date? {
        guard let data = periodPredictionData(
            settings: settings,
            eventReader: eventReader,
            target: today
        ) else {
            return nil
        }
        guard let rangeStart = calendar.date(
            byAdding: .day,
            value: -max(data.context.cycleLength, 1),
            to: today.startOfDay
        )?.startOfDay,
              let rangeEndExclusive = calendar.date(
                byAdding: .day,
                value: 1,
                to: today.startOfDay
              )?.startOfDay else {
            return nil
        }

        let predictedStarts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: rangeStart,
            rangeEndExclusive: rangeEndExclusive,
            today: today,
            settings: settings,
            periodSummaries: data.summaries,
            pillDates: data.pillDates,
            calendar: calendar
        )

        return PeriodForecastCalculator.delayedPeriodStart(
            for: today,
            predictedStarts: predictedStarts,
            predictedLength: data.context.predictedLength,
            calendar: calendar
        )
    }

    private func periodPredictionData(
        settings: UserSettings,
        eventReader: EventReading,
        target: Date
    ) -> (context: PeriodPredictionContext, summaries: [PeriodSummary], pillDates: Set<Date>)? {
        let periodEvents = eventReader.events(of: .period).map { $0.date }
        let summaries = PeriodSummaryBuilder.build(from: periodEvents)
        let pillDates = Set(eventReader.events(of: .pill).map { $0.date.startOfDay })
        guard let context = PeriodForecastCalculator.predictionContext(
            target: target,
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            calendar: calendar
        ) else {
            return nil
        }
        return (context: context, summaries: summaries, pillDates: pillDates)
    }
    
    private func nextPillStartDate(
        settings: UserSettings,
        eventReader: EventReading,
        today: Date
    ) -> Date? {
        let pillDates = Set(eventReader.events(of: .pill).map { $0.date.startOfDay })
        guard let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        ) else { return nil }
        
        guard let first = calendar.date(byAdding: .day, value: projection.breakDays + 1, to: projection.projectedLastIntakeDate.startOfDay) else {
            return nil
        }
        
        var nextStart = first.startOfDay
        while nextStart <= today {
            guard let candidate = calendar.date(byAdding: .day, value: projection.cycleLength, to: nextStart) else {
                return nil
            }
            nextStart = candidate
        }
        return nextStart
    }
    
    private func pillScheduleInfo(
        settings: UserSettings,
        eventReader: EventReading
    ) -> PillCycleProjection? {
        let pillDates = Set(eventReader.events(of: .pill).map { $0.date.startOfDay })
        return PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        )
    }
    
    private func nextPillStartDates(
        settings: UserSettings,
        eventReader: EventReading,
        count: Int,
        today: Date
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard let first = nextPillStartDate(
            settings: settings,
            eventReader: eventReader,
            today: today
        ) else {
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
        time: DateComponents,
        now: Date
    ) -> [Date] {
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
        case 0:
            return "오늘은 생리 예정일 입니다."
        case 1:
            return "생리 예정일 하루 전입니다."
        default:
            return "생리 예정일이 \(daysBefore)일 남았습니다."
        }
    }
    
    private func pillPurchaseReminderBody(daysBefore: Int) -> String {
        switch daysBefore {
        case 0:
            return "오늘부터 새로운 피임약 복용이 시작됩니다. 잊지 말고 복용해주세요."
        case 1:
            return "내일부터 새로운 피임약 복용이 시작됩니다. 미리 준비해주세요."
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
    
    private static let periodReminderId = "notification.period.reminder"
    private static let periodDelayedId = "notification.period.delayed"
    private static let pillPurchaseReminderId = "notification.pill.purchase"
    private static let maxPeriodReminderLeadDays = 7
    private static let periodReminderIds = (0..<(maxScheduledOccurrences * maxPeriodReminderLeadDays)).map {
        "\(periodReminderId).\($0)"
    }
    private static let periodDelayedIds = (0..<maxScheduledOccurrences).map { "\(periodDelayedId).\($0)" }
    private static let pillPurchaseReminderIds = (0..<maxScheduledOccurrences).map { "\(pillPurchaseReminderId).\($0)" }
    private static let identifiers: [String] = [
        periodReminderId,
        periodDelayedId,
        pillPurchaseReminderId
    ] + periodReminderIds + PillReminderNotificationScheduler.identifiers + periodDelayedIds + pillPurchaseReminderIds
}
