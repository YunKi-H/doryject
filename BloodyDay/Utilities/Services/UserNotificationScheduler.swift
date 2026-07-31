//
//  UserNotificationScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation
import UserNotifications

final class UserNotificationScheduler: NotificationScheduler {
    private static let rescheduleCoordinator = NotificationRescheduleCoordinator()
    private static let submissionCounter = NotificationScheduleSubmissionCounter()

    private let center: UNUserNotificationCenter
    private let configuredCalendar: Calendar?
    private let nowProvider: () -> Date
    private var calendar: Calendar {
        configuredCalendar ?? .autoupdatingCurrent
    }
    private static let maxScheduledOccurrences = 3
    private let maxScheduledOccurrences = UserNotificationScheduler.maxScheduledOccurrences

    init(
        calendar: Calendar? = nil,
        center: UNUserNotificationCenter = .current(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.configuredCalendar = calendar
        self.center = center
        self.nowProvider = nowProvider
    }
    
    func apply(settings: UserSettings, eventRepository: EventRepository) {
        let sequence = Self.submissionCounter.next()
        let submission = makeSubmission(
            sequence: sequence,
            settings: settings,
            eventReader: eventRepository,
            requestsAuthorization: true
        )
        Task {
            await Self.rescheduleCoordinator.apply(
                submission,
                center: center
            )
        }
    }

    func applyAndWait(
        settings: UserSettings,
        eventReader: EventReading
    ) async {
        let sequence = Self.submissionCounter.next()
        let submission = makeSubmission(
            sequence: sequence,
            settings: settings,
            eventReader: eventReader,
            requestsAuthorization: false
        )
        await Self.rescheduleCoordinator.apply(submission, center: center)
        _ = await center.pendingNotificationRequests()
    }

    private func makeSubmission(
        sequence: Int,
        settings: UserSettings,
        eventReader: EventReading,
        requestsAuthorization: Bool
    ) -> NotificationScheduleSubmission {
        if requestsAuthorization {
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        let now = nowProvider()
        let today = calendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []
        
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
                    requests.append(notificationRequest(
                        identifier: Self.periodReminderIds[idIndex],
                        title: "B-Day",
                        body: body,
                        date: reminderDate
                    ))
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
            if today > calendar.startOfDay(for: currentExpectedStart) {
                let scheduled = nextOccurrences(
                    time: notificationSettings.periodReminderTime,
                    from: now,
                    count: maxScheduledOccurrences
                )
                for (index, date) in scheduled.enumerated() {
                    guard index < Self.periodDelayedIds.count else { break }
                    let daysDelayed = max(
                        calendar.dateComponents(
                            [.day],
                            from: calendar.startOfDay(for: currentExpectedStart),
                            to: calendar.startOfDay(for: date)
                        ).day ?? 0,
                        0
                    )
                    requests.append(notificationRequest(
                        identifier: Self.periodDelayedIds[index],
                        title: "B-Day",
                        body: periodDelayedBody(daysDelayed: daysDelayed),
                        date: date
                    ))
                }
            }
        }
        let pillDates = Set(eventReader.events(of: .pill).map {
            calendar.startOfDay(for: $0.date)
        })
        requests.append(contentsOf:
            PillReminderNotificationScheduler.notificationRequests(
                settings: settings,
                pillDates: pillDates,
                pillCycles: eventReader.pillCycles(),
                now: now,
                calendar: calendar
            )
        )
        if notificationSettings.pillPurchaseReminderEnabled,
           pillScheduleInfo(
            settings: settings,
            eventReader: eventReader,
            today: today
           ) != nil {
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
                requests.append(notificationRequest(
                    identifier: Self.pillPurchaseReminderIds[index],
                    title: "B-Day",
                    body: pillPurchaseReminderBody(daysBefore: max(notificationSettings.pillPurchaseReminderDaysBefore, 0)),
                    date: reminder
                ))
            }
        }
        return NotificationScheduleSubmission(
            sequence: sequence,
            requests: requests,
            managedIdentifiers: Self.identifiers
        )
    }
    
    private func notificationRequest(
        identifier: String,
        title: String,
        body: String,
        date: Date
    ) -> UNNotificationRequest {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.second = 0
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
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

        let horizonDays = data.context.recurringCycleLength * max(count + 4, 1)
        guard let horizonEndExclusive = calendar.date(
            byAdding: .day,
            value: horizonDays,
            to: calendar.startOfDay(for: today)
        ) else {
            return []
        }
        let normalizedHorizonEnd = calendar.startOfDay(for: horizonEndExclusive)

        let validStarts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: today,
            rangeEndExclusive: normalizedHorizonEnd,
            today: today,
            settings: settings,
            periodSummaries: data.summaries,
            pillDates: data.pillDates,
            pillCycles: data.pillCycles,
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
            value: -data.context.recurringCycleLength,
            to: calendar.startOfDay(for: today)
        ),
              let rangeEndExclusive = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: today)
              ) else {
            return nil
        }
        let normalizedRangeStart = calendar.startOfDay(for: rangeStart)
        let normalizedRangeEnd = calendar.startOfDay(for: rangeEndExclusive)

        let predictedStarts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: normalizedRangeStart,
            rangeEndExclusive: normalizedRangeEnd,
            today: today,
            settings: settings,
            periodSummaries: data.summaries,
            pillDates: data.pillDates,
            pillCycles: data.pillCycles,
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
    ) -> (
        context: PeriodPredictionContext,
        summaries: [PeriodSummary],
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo]
    )? {
        let periodEvents = eventReader.events(of: .period).map { $0.date }
        let summaries = PeriodSummaryBuilder.build(
            from: periodEvents,
            calendar: calendar
        )
        let pillDates = Set(eventReader.events(of: .pill).map {
            calendar.startOfDay(for: $0.date)
        })
        let pillCycles = eventReader.pillCycles()
        guard let context = PeriodForecastCalculator.predictionContext(
            target: target,
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            pillCycles: pillCycles,
            calendar: calendar
        ) else {
            return nil
        }
        return (
            context: context,
            summaries: summaries,
            pillDates: pillDates,
            pillCycles: pillCycles
        )
    }
    
    private func nextPillStartDate(
        settings: UserSettings,
        eventReader: EventReading,
        today: Date
    ) -> Date? {
        let pillDates = Set(eventReader.events(of: .pill).map {
            calendar.startOfDay(for: $0.date)
        })
        guard let projection = PeriodForecastCalculator.activePillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            pillCycles: eventReader.pillCycles(),
            on: today,
            calendar: calendar
        ) else { return nil }
        
        guard let first = calendar.date(
            byAdding: .day,
            value: projection.breakDays + 1,
            to: calendar.startOfDay(for: projection.projectedLastIntakeDate)
        ) else {
            return nil
        }
        
        var nextStart = calendar.startOfDay(for: first)
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
        eventReader: EventReading,
        today: Date
    ) -> PillCycleProjection? {
        let pillDates = Set(eventReader.events(of: .pill).map {
            calendar.startOfDay(for: $0.date)
        })
        return PeriodForecastCalculator.activePillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            pillCycles: eventReader.pillCycles(),
            on: today,
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
        let cycleLength = max(
            pillSettings.pillCount + pillSettings.pillBreakDuration,
            0
        )
        guard cycleLength > 0 else { return [] }
        
        var results: [Date] = []
        var next = calendar.startOfDay(for: first)
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
            guard let base = calendar.date(
                byAdding: .day,
                value: -daysBefore,
                to: calendar.startOfDay(for: start)
            ),
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

struct NotificationScheduleSequencePolicy {
    private(set) var latestAppliedSequence = 0

    mutating func shouldApply(_ sequence: Int) -> Bool {
        guard sequence > latestAppliedSequence else { return false }
        latestAppliedSequence = sequence
        return true
    }
}

struct NotificationScheduleSubmission: @unchecked Sendable {
    let sequence: Int
    let requests: [UNNotificationRequest]
    let managedIdentifiers: [String]
}

actor NotificationRescheduleCoordinator {
    private var sequencePolicy = NotificationScheduleSequencePolicy()

    func apply(
        _ submission: NotificationScheduleSubmission,
        center: UNUserNotificationCenter
    ) {
        guard sequencePolicy.shouldApply(submission.sequence) else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: submission.managedIdentifiers
        )
        submission.requests.forEach { center.add($0) }
    }
}

private final class NotificationScheduleSubmissionCounter:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var sequence = 0

    func next() -> Int {
        lock.withLock {
            sequence += 1
            return sequence
        }
    }
}
