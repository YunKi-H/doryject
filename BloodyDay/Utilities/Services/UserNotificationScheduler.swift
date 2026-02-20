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
            var idIndex = 0
            for start in starts {
                for offset in stride(from: daysBefore, through: 0, by: -1) {
                    guard idIndex < Self.periodReminderIds.count else { break }
                    guard let reminderBase = calendar.date(byAdding: .day, value: -offset, to: start),
                          let reminderDate = combineDate(reminderBase, time: notificationSettings.periodReminderTime),
                          reminderDate > Date() else {
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
           let context = periodPredictionContext(settings: settings, eventRepository: eventRepository),
           let currentExpectedStart = cycleAlignedExpectedStartDate(
            target: Date().startOfDay,
            firstExpected: context.firstExpected,
            cycleLength: context.cycleLength,
            predictedLength: context.predictedLength
           ) {
            let today = Date().startOfDay
            if today > currentExpectedStart.startOfDay {
                let scheduled = nextOccurrences(
                    time: notificationSettings.periodReminderTime,
                    from: Date(),
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
        if notificationSettings.pillReminderEnabled,
           pillScheduleInfo(settings: settings, eventRepository: eventRepository) != nil {
            let reminders = nextPillReminderDates(
                settings: settings,
                eventRepository: eventRepository,
                time: notificationSettings.pillReminderTime,
                count: maxScheduledOccurrences
            )
            for (index, reminder) in reminders.enumerated() {
                guard index < Self.pillReminderIds.count else { break }
                scheduleOnce(
                    identifier: Self.pillReminderIds[index],
                    title: "B-Day",
                    body: "피임약을 복용하실 시간입니다.",
                    date: reminder
                )
            }
        }
        if notificationSettings.pillPurchaseReminderEnabled,
           pillScheduleInfo(settings: settings, eventRepository: eventRepository) != nil {
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
        eventRepository: EventRepository,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard let context = periodPredictionContext(settings: settings, eventRepository: eventRepository) else {
            return []
        }
        
        let today = Date().startOfDay
        guard var next = cycleAlignedExpectedStartDate(
            target: today,
            firstExpected: context.firstExpected,
            cycleLength: context.cycleLength,
            predictedLength: context.predictedLength
        )?.startOfDay else {
            return []
        }
        while next < today {
            guard let following = calendar.date(byAdding: .day, value: context.cycleLength, to: next) else { return [] }
            next = following.startOfDay
        }
        
        var results: [Date] = []
        for _ in 0..<count {
            results.append(next)
            guard let following = calendar.date(byAdding: .day, value: context.cycleLength, to: next) else { break }
            next = following.startOfDay
        }
        return results
    }
    
    private func periodPredictionContext(
        settings: UserSettings,
        eventRepository: EventRepository
    ) -> (firstExpected: Date, cycleLength: Int, predictedLength: Int)? {
        let predictedLength = max(predictedPeriodLengthDays(settings: settings, eventRepository: eventRepository) ?? 5, 1)
        
        if let pill = pillPredictionContext(settings: settings, eventRepository: eventRepository) {
            return (pill.firstExpected, pill.cycleLength, predictedLength)
        }
        
        let periodEvents = eventRepository.events(of: .period).map { $0.date }
        let summaries = PeriodSummaryBuilder.build(from: periodEvents)
        guard let lastStart = summaries.map(\.start).max()?.startOfDay,
              let cycle = cycleLengthDays(settings: settings, summaries: summaries),
              cycle > 0,
              let firstExpected = calendar.date(byAdding: .day, value: cycle, to: lastStart)?.startOfDay else {
            return nil
        }
        return (firstExpected, cycle, predictedLength)
    }
    
    private func pillPredictionContext(
        settings: UserSettings,
        eventRepository: EventRepository
    ) -> (firstExpected: Date, cycleLength: Int)? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let anchor = mostRecentPillStart(from: pillDates) else { return nil }
        guard let lastPillInCycle = calendar.date(byAdding: .day, value: pillCount - 1, to: anchor.startOfDay),
              let firstExpected = calendar.date(byAdding: .day, value: 3, to: lastPillInCycle)?.startOfDay else {
            return nil
        }
        return (firstExpected, cycleLength)
    }
    
    private func predictedPeriodLengthDays(
        settings: UserSettings,
        eventRepository: EventRepository
    ) -> Int? {
        let settingsPeriod = settings.period
        if settingsPeriod.autoCyclePredictionEnabled == false,
           let manual = settingsPeriod.averagePeriodDays,
           manual > 0 {
            return manual
        }
        
        let periodEvents = eventRepository.events(of: .period).map { $0.date }
        let summaries = PeriodSummaryBuilder.build(from: periodEvents)
        let lengths = summaries.map(\.lengthDays).filter { $0 > 0 }
        guard !lengths.isEmpty else { return nil }
        let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
        return Int(round(avg))
    }
    
    private func cycleAlignedExpectedStartDate(
        target: Date,
        firstExpected: Date,
        cycleLength: Int,
        predictedLength: Int
    ) -> Date? {
        let today = Date().startOfDay
        guard cycleLength > 0 else { return firstExpected.startOfDay }
        
        if target <= firstExpected.startOfDay {
            return firstExpected.startOfDay
        }
        
        let daysFromFirst = calendar.dateComponents([.day], from: firstExpected.startOfDay, to: target.startOfDay).day ?? 0
        let cycleOffset = daysFromFirst / cycleLength
        guard let cycleStart = calendar.date(byAdding: .day, value: cycleOffset * cycleLength, to: firstExpected.startOfDay)?.startOfDay else {
            return firstExpected.startOfDay
        }
        
        let cycleEndExclusive = calendar.date(byAdding: .day, value: max(predictedLength, 1), to: cycleStart.startOfDay) ?? cycleStart
        if target > today && target >= cycleEndExclusive {
            return calendar.date(byAdding: .day, value: cycleLength, to: cycleStart)?.startOfDay
        }
        return cycleStart
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
        guard pillSettings.pillEnabled else { return nil }
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
    
    private func pillScheduleInfo(
        settings: UserSettings,
        eventRepository: EventRepository
    ) -> (anchor: Date, cycleLength: Int, pillCount: Int, breakDays: Int)? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let anchor = mostRecentPillStart(from: pillDates) else { return nil }
        return (anchor, cycleLength, pillCount, breakDays)
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
    
    private func nextPillReminderDates(
        settings: UserSettings,
        eventRepository: EventRepository,
        time: DateComponents,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }
        guard let info = pillScheduleInfo(settings: settings, eventRepository: eventRepository) else { return [] }
        
        let now = Date()
        let today = now.startOfDay
        var reminders: [Date] = []
        var dayOffset = 0
        let maxLookahead = max(info.cycleLength * 3, 90)
        
        while reminders.count < count && dayOffset <= maxLookahead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { break }
            let daysFromAnchor = calendar.dateComponents([.day], from: info.anchor.startOfDay, to: day.startOfDay).day ?? -1
            if daysFromAnchor >= 0 {
                let indexInCycle = daysFromAnchor % info.cycleLength
                if indexInCycle < info.pillCount,
                   let reminderDate = combineDate(day, time: time),
                   reminderDate > now {
                    reminders.append(reminderDate)
                }
            }
            dayOffset += 1
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
    private static let maxPeriodReminderLeadDays = 7
    private static let periodReminderIds = (0..<(maxScheduledOccurrences * maxPeriodReminderLeadDays)).map {
        "\(periodReminderId).\($0)"
    }
    private static let pillReminderIds = (0..<maxScheduledOccurrences).map { "\(pillReminderId).\($0)" }
    private static let periodDelayedIds = (0..<maxScheduledOccurrences).map { "\(periodDelayedId).\($0)" }
    private static let pillPurchaseReminderIds = (0..<maxScheduledOccurrences).map { "\(pillPurchaseReminderId).\($0)" }
    private static let identifiers: [String] = [
        periodReminderId,
        periodDelayedId,
        pillReminderId,
        pillPurchaseReminderId
    ] + periodReminderIds + pillReminderIds + periodDelayedIds + pillPurchaseReminderIds
}
