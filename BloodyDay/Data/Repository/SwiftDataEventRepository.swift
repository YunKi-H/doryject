//
//  SwiftDataEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 11/27/25.
//
//

import Foundation
import SwiftData

final class SwiftDataEventRepository: EventRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: - CRUD
    func save(_ event: UserEvent) {
        // If the object is already in the context, just try saving. Otherwise, insert then save.
        do {
            let eventID = event.id
            let existing = try context.fetch(
                FetchDescriptor<UserEvent>(predicate: #Predicate { $0.id == eventID })
            )
            if existing.isEmpty {
                context.insert(event)
            }
        } catch {
            assertionFailure("SwiftData save failed: \(error)")
        }
    }

    func delete(id: UUID) {
        // Fetch the event by id and delete
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            let results = try context.fetch(descriptor)
            results.forEach { context.delete($0) }
            if !results.isEmpty {
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData delete failed: \(error)")
        }
    }
    
    func delete(type: EventType, on: Date) {
        let startOfDay = on.startOfDay
        let endOfDay = on.endOfDay
        // Fetch the event by id and delete
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date <= endOfDay && $0.type == type }
        )
        do {
            let results = try context.fetch(descriptor)
            results.forEach { context.delete($0) }
            if !results.isEmpty {
                try context.save()
            }
        } catch {
            assertionFailure("SwiftData delete failed: \(error)")
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
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate { $0.type == type },
            sortBy: [ .init(\UserEvent.date, order: .forward) ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            assertionFailure("SwiftData fetch by type failed: \(error)")
            return []
        }
    }
}

//// MARK: - Small Calendar helpers
//private extension DateComponents {
//    func date(byAddingTo base: Date, using calendar: Calendar) -> Date? {
//        calendar.date(byAdding: self, to: base)
//    }
//}
