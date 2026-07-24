//
//  AppleCalendarSyncService.swift
//  BloodyDay
//
//  Created by Yunki on 1/10/26.
//

import Foundation

final class AppleCalendarSyncService {
    private let fullSyncCoordinator = AppleCalendarFullSyncCoordinator()
    private let settingsRepository: SettingsRepository
    private let eventReader: EventReading
    private let calendarClient: AppleCalendarClient
    private let syncStore: AppleCalendarSyncStore
    private let nowProvider: () -> Date
    private let supportedTypes: [EventType] = [.period, .pill, .love]
    private let predictedPeriodSyncHorizonYears = 1
    
    init(
        settingsRepository: SettingsRepository,
        eventRepository: EventReading,
        calendarClient: AppleCalendarClient,
        syncStore: AppleCalendarSyncStore,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.settingsRepository = settingsRepository
        self.eventReader = eventRepository
        self.calendarClient = calendarClient
        self.syncStore = syncStore
        self.nowProvider = nowProvider
    }
    
    func syncAll() async {
        guard await fullSyncCoordinator.beginOrMarkPending() else {
            return
        }

        repeat {
            await performFullSync()
        } while await fullSyncCoordinator.finishPassAndShouldRunAgain()
    }

    private func performFullSync() async {
        var settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard await calendarClient.requestAccess() else { return }
        
        var validIds: Set<UUID> = []
        
        for type in supportedTypes {
            if settings.appleCalendar.eventSyncEnabled[type] == true {
                if let calendarId = await ensureCalendar(for: type, settings: &settings) {
                    let title = calendarTitle(for: type, settings: settings)
                    if type == .period {
                        let summaries = PeriodSummaryBuilder.build(from: eventReader.events(of: .period).map { $0.date })
                        for summary in summaries {
                            let syntheticId = periodSummaryId(start: summary.start)
                            validIds.insert(syntheticId)
                            await upsertPeriodSummary(
                                summary,
                                calendarIdentifier: calendarId,
                                syntheticId: syntheticId,
                                title: title
                            )
                        }
                        let predictedSummaries = predictedPeriodSummaries(
                            settings: settings,
                            actualPeriodSummaries: summaries,
                            today: nowProvider()
                        )
                        for summary in predictedSummaries {
                            let syntheticId = predictedPeriodSummaryId(start: summary.start)
                            validIds.insert(syntheticId)
                            await upsertPeriodSummary(
                                summary,
                                calendarIdentifier: calendarId,
                                syntheticId: syntheticId,
                                title: title
                            )
                        }
                    } else {
                        let events = eventReader.events(of: type)
                        for event in events {
                            validIds.insert(event.id)
                            await upsert(
                                event: event,
                                type: type,
                                calendarIdentifier: calendarId,
                                dateRange: nil,
                                title: title
                            )
                        }
                    }
                }
            } else {
                removeEvents(for: type)
            }
        }
        
        removeOrphanedRecords(validIds: validIds)
    }
    
    func syncUpsert(event: UserEvent) async {
        let settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard supportedTypes.contains(event.type) else { return }
        guard settings.appleCalendar.eventSyncEnabled[event.type] == true else { return }
        guard await calendarClient.requestAccess() else { return }
        
        if event.type == .period {
            await syncAll()
            return
        }
        
        var mutableSettings = settings
        guard let calendarId = await ensureCalendar(for: event.type, settings: &mutableSettings) else { return }
        let title = calendarTitle(for: event.type, settings: settings)
        await upsert(
            event: event,
            type: event.type,
            calendarIdentifier: calendarId,
            dateRange: nil,
            title: title
        )
    }
    
    func syncDelete(eventId: UUID, eventType: EventType?) async {
        let settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard await calendarClient.requestAccess() else { return }
        
        if eventType == .period {
            await syncAll()
            return
        }
        
        if let record = syncStore.record(for: eventId) {
            calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
            syncStore.remove(for: eventId)
        } else if let type = eventType, supportedTypes.contains(type) {
            // No record found, nothing to delete.
        }
    }
    
    func syncDelete(events: [UserEvent]) async {
        guard !events.isEmpty else { return }
        let settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard await calendarClient.requestAccess() else { return }
        
        if events.contains(where: { $0.type == .period }) {
            await syncAll()
            return
        }
        
        for event in events {
            if let record = syncStore.record(for: event.id) {
                calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
                syncStore.remove(for: event.id)
            }
        }
    }
    
    func disableAll(calendarIdentifiers: [EventType: String]) async {
        guard await calendarClient.requestAccess() else { return }
        for identifier in calendarIdentifiers.values {
            calendarClient.removeCalendar(identifier: identifier)
        }
        syncStore.removeAll()
    }
    
    func disable(type: EventType, calendarIdentifier: String?) async {
        guard await calendarClient.requestAccess() else { return }
        if let identifier = calendarIdentifier {
            calendarClient.removeCalendar(identifier: identifier)
        }
        removeRecords(for: type)
    }
    
    private func ensureCalendar(
        for type: EventType,
        settings: inout UserSettings
    ) async -> String? {
        let name = settings.appleCalendar.calendarNames[type]
        ?? AppleCalendarSettings.defaultCalendarNames[type, default: "BloodyDay"]
        let existing = settings.appleCalendar.calendarIdentifiers[type]
        let identifier = calendarClient.createOrFetchCalendar(name: name, existingIdentifier: existing)
        if let identifier {
            settings.appleCalendar.calendarIdentifiers[type] = identifier
            settingsRepository.save(settings)
        }
        return identifier
    }
    
    private func upsert(
        event: UserEvent,
        type: EventType,
        calendarIdentifier: String,
        dateRange: DateInterval?,
        title: String
    ) async {
        let existing = syncStore.record(for: event.id)?.ekEventIdentifier
        if let ekId = calendarClient.upsertEvent(
            event: event,
            calendarIdentifier: calendarIdentifier,
            title: title,
            existingEventIdentifier: existing,
            dateRange: dateRange
        ) {
            let record = AppleCalendarSyncRecord(
                userEventId: event.id,
                eventType: type,
                calendarIdentifier: calendarIdentifier,
                ekEventIdentifier: ekId,
                lastSyncedAt: Date()
            )
            syncStore.upsert(record)
        }
    }
    
    private func removeEvents(for type: EventType) {
        let records = syncStore.records().filter { $0.eventType == type }
        for record in records {
            calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
            syncStore.remove(for: record.userEventId)
        }
    }
    
    private func removeRecords(for type: EventType) {
        let records = syncStore.records().filter { $0.eventType == type }
        for record in records {
            syncStore.remove(for: record.userEventId)
        }
    }
    
    private func removeOrphanedRecords(validIds: Set<UUID>) {
        for record in syncStore.records() where !validIds.contains(record.userEventId) {
            calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
            syncStore.remove(for: record.userEventId)
        }
    }
    
    private func calendarTitle(for type: EventType, settings: UserSettings) -> String {
        settings.appleCalendar.calendarNames[type]
        ?? AppleCalendarSettings.defaultCalendarNames[type, default: "BloodyDay"]
    }
    
    private func periodSummaryId(start: Date) -> UUID {
        syntheticSummaryId(start: start, prefix: "00000000-0000-0000-0000")
    }

    private func predictedPeriodSummaryId(start: Date) -> UUID {
        syntheticSummaryId(start: start, prefix: "11111111-1111-1111-1111")
    }

    private func syntheticSummaryId(start: Date, prefix: String) -> UUID {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: start.startOfDay)
        let dayKey = (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
        let suffix = String(format: "%012d", dayKey)
        let uuidString = "\(prefix)-\(suffix)"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func predictedPeriodSummaries(
        settings: UserSettings,
        actualPeriodSummaries: [PeriodSummary],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [PeriodSummary] {
        let normalizedToday = today.startOfDay
        guard let horizonEndExclusive = calendar.date(
            byAdding: .year,
            value: predictedPeriodSyncHorizonYears,
            to: normalizedToday
        )?.startOfDay else {
            return []
        }

        let pillDates = Set(eventReader.events(of: .pill).map { $0.date.startOfDay })
        guard let context = PeriodForecastCalculator.predictionContext(
            target: normalizedToday,
            settings: settings,
            periodSummaries: actualPeriodSummaries,
            pillDates: pillDates,
            calendar: calendar
        ) else {
            return []
        }

        let validStarts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: normalizedToday,
            rangeEndExclusive: horizonEndExclusive,
            today: normalizedToday,
            settings: settings,
            periodSummaries: actualPeriodSummaries,
            pillDates: pillDates,
            calendar: calendar
        )
        guard validStarts.isEmpty == false else { return [] }

        let lengthDays = max(context.predictedLength, 1)
        return validStarts.compactMap { start in
            guard let end = calendar.date(byAdding: .day, value: lengthDays - 1, to: start.startOfDay)?.startOfDay else {
                return nil
            }
            guard end >= normalizedToday, start < horizonEndExclusive else {
                return nil
            }
            return PeriodSummary(
                start: start.startOfDay,
                end: end,
                lengthDays: lengthDays,
                cycleDays: context.cycleLength
            )
        }
    }
    
    private func upsertPeriodSummary(
        _ summary: PeriodSummary,
        calendarIdentifier: String,
        syntheticId: UUID,
        title: String
    ) async {
        let range = DateInterval(start: summary.start.startOfDay, end: summary.end.endOfDay)
        let syntheticEvent = UserEvent(id: syntheticId, date: summary.start, type: .period)
        await upsert(
            event: syntheticEvent,
            type: .period,
            calendarIdentifier: calendarIdentifier,
            dateRange: range,
            title: title
        )
    }
}

actor AppleCalendarFullSyncCoordinator {
    private var isRunning = false
    private var needsRerun = false

    func beginOrMarkPending() -> Bool {
        if isRunning {
            needsRerun = true
            return false
        }
        isRunning = true
        return true
    }

    func finishPassAndShouldRunAgain() -> Bool {
        if needsRerun {
            needsRerun = false
            return true
        }
        isRunning = false
        return false
    }
}
