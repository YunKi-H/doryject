//
//  SwiftDataEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 11/27/25.
//

import Foundation
import SwiftData

final class SwiftDataEventRepository: EventRepository {
    private let context: ModelContext
    private let configuredCalendar: Calendar?
    private let settingsRepository: SettingsRepository

    private var calendar: Calendar {
        configuredCalendar ?? .current
    }
    
    init(
        context: ModelContext,
        calendar: Calendar? = nil,
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository()
    ) {
        self.context = context
        self.configuredCalendar = calendar
        self.settingsRepository = settingsRepository
        normalizeStoredEventDates()
        PillCyclePersistence.migrateIfNeeded(
            in: context,
            settings: settingsRepository.load(),
            calendar: self.calendar
        )
    }
    
    // MARK: - CRUD
    func save(_ event: UserEvent) {
        do {
            event.normalizeDate(calendar: calendar)
            let eventKey = event.uniqueKey
            
            let descriptor = FetchDescriptor<UserEvent>(
                predicate: #Predicate { $0.uniqueKey == eventKey }
            )
            
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                event.uniqueKey = eventKey
                try PillCyclePersistence.assignCycle(
                    to: event,
                    in: context,
                    settings: settingsRepository.load(),
                    calendar: calendar
                )
                context.insert(event)
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
    
    func delete(id: UUID) {
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            let results = try context.fetch(descriptor)
            let cycleIDs = Set(results.compactMap(\.pillCycleID))
            results.forEach { context.delete($0) }
            if !results.isEmpty {
                try PillCyclePersistence.cleanupAfterDeletion(
                    cycleIDs: cycleIDs,
                    in: context,
                    calendar: calendar
                )
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData delete failed: \(error)")
        }
    }
    
    func delete(type: EventType, on: Date) {
        let eventKey = UserEvent.makeUniqueKey(date: on, type: type, calendar: calendar)
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.uniqueKey == eventKey }
        )
        do {
            let results = try context.fetch(descriptor)
            let cycleIDs = Set(results.compactMap(\.pillCycleID))
            results.forEach { context.delete($0) }
            if !results.isEmpty {
                try PillCyclePersistence.cleanupAfterDeletion(
                    cycleIDs: cycleIDs,
                    in: context,
                    calendar: calendar
                )
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData delete failed: \(error)")
        }
    }
    
    func replace(type: EventType, on dates: Set<Date>) {
        let rawValue = type.rawValue
        let normalizedDates = Set(dates.map { calendar.startOfDay(for: $0) })
        do {
            let descriptor = FetchDescriptor<UserEvent>(
                predicate: #Predicate { $0.typeRaw == rawValue }
            )
            let existing = try context.fetch(descriptor)
            let existingKeys = Set(existing.map(\.uniqueKey))
            let targetKeys = Set(normalizedDates.map {
                UserEvent.makeUniqueKey(date: $0, type: type, calendar: calendar)
            })
            
            var changed = false
            var deletedCycleIDs: Set<UUID> = []
            for event in existing where !targetKeys.contains(event.uniqueKey) {
                if let cycleID = event.pillCycleID {
                    deletedCycleIDs.insert(cycleID)
                }
                context.delete(event)
                changed = true
            }
            
            for day in normalizedDates.sorted() {
                let key = UserEvent.makeUniqueKey(date: day, type: type, calendar: calendar)
                if !existingKeys.contains(key) {
                    let event = UserEvent(date: day, type: type, calendar: calendar)
                    try PillCyclePersistence.assignCycle(
                        to: event,
                        in: context,
                        settings: settingsRepository.load(),
                        calendar: calendar
                    )
                    context.insert(event)
                    changed = true
                }
            }
            
            if changed {
                try PillCyclePersistence.cleanupAfterDeletion(
                    cycleIDs: deletedCycleIDs,
                    in: context,
                    calendar: calendar
                )
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData replace failed: \(error)")
        }
    }
    
    func allEvents() -> [UserEvent] {
        do {
            return normalizeAndSort(
                try context.fetch(FetchDescriptor<UserEvent>())
            )
        } catch {
            assertionFailure("SwiftData fetch all failed: \(error)")
            return []
        }
    }
    
    func events(forMonth month: Date) -> [UserEvent] {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return []
        }

        do {
            return normalizeAndSort(
                try context.fetch(FetchDescriptor<UserEvent>())
            ).filter { $0.date >= start && $0.date < end }
        } catch {
            assertionFailure("SwiftData fetch month failed: \(error)")
            return []
        }
    }
    
    func events(of type: EventType) -> [UserEvent] {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.typeRaw == rawValue }
        )
        do {
            return normalizeAndSort(try context.fetch(descriptor))
        } catch {
            assertionFailure("SwiftData fetch by type failed: \(error)")
            return []
        }
    }

    func pillCycles() -> [PillCycleInfo] {
        PillCyclePersistence.cycleInfos(in: context, calendar: calendar)
    }

    private func normalizeStoredEventDates() {
        do {
            let events = try context.fetch(FetchDescriptor<UserEvent>())
            let changed = events.reduce(false) { result, event in
                event.normalizeDate(calendar: calendar) || result
            }
            if changed {
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData date normalization failed: \(error)")
        }
    }

    private func normalizeAndSort(_ events: [UserEvent]) -> [UserEvent] {
        events
            .map { event in
                event.normalizeDate(calendar: calendar)
                return event
            }
            .sorted { $0.date < $1.date }
    }
}
