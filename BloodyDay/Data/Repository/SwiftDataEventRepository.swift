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
    private let calendar: Calendar
    private let settingsRepository: SettingsRepository
    
    init(
        context: ModelContext,
        calendar: Calendar = .current,
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository()
    ) {
        self.context = context
        self.calendar = calendar
        self.settingsRepository = settingsRepository
        PillCyclePersistence.migrateIfNeeded(
            in: context,
            settings: settingsRepository.load(),
            calendar: calendar
        )
    }
    
    // MARK: - CRUD
    func save(_ event: UserEvent) {
        do {
            let eventKey = UserEvent.makeUniqueKey(date: event.date, type: event.type, calendar: calendar)
            
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
                try PillCyclePersistence.cleanupAfterDeletion(cycleIDs: cycleIDs, in: context)
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
                try PillCyclePersistence.cleanupAfterDeletion(cycleIDs: cycleIDs, in: context)
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData delete failed: \(error)")
        }
    }
    
    func replace(type: EventType, on dates: Set<Date>) {
        let rawValue = type.rawValue
        let normalizedDates = Set(dates.map(\.startOfDay))
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
                    in: context
                )
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData replace failed: \(error)")
        }
    }
    
    func allEvents() -> [UserEvent] {
        let descriptor = FetchDescriptor<UserEvent>(sortBy: [
            .init(\UserEvent.date, order: .forward)
        ])
        do {
            return try context.fetch(descriptor)
        } catch {
            assertionFailure("SwiftData fetch all failed: \(error)")
            return []
        }
    }
    
    func events(forMonth month: Date) -> [UserEvent] {
        // Compute start/end of month range
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return []
        }
        
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [ .init(\UserEvent.date, order: .forward) ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            assertionFailure("SwiftData fetch month failed: \(error)")
            return []
        }
    }
    
    func events(of type: EventType) -> [UserEvent] {
        let rawValue = type.rawValue
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.typeRaw == rawValue },
            sortBy: [ .init(\UserEvent.date, order: .forward) ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            assertionFailure("SwiftData fetch by type failed: \(error)")
            return []
        }
    }

    func pillCycles() -> [PillCycleInfo] {
        PillCyclePersistence.cycleInfos(in: context)
    }
}
