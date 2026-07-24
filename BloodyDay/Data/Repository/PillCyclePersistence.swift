//
//  PillCyclePersistence.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import SwiftData

enum PillCyclePersistence {
    private static let maximumContinuityGap = 4

    static func migrateIfNeeded(
        in context: ModelContext,
        settings: UserSettings,
        today: Date = .now,
        calendar: Calendar = .current
    ) {
        do {
            guard try context.fetchCount(FetchDescriptor<PillCycle>()) == 0 else { return }

            let pillEvents = try fetchPillEvents(in: context)
            guard pillEvents.isEmpty == false else { return }

            let groups = historicalGroups(events: pillEvents, calendar: calendar)
            let latestGroupIndex = groups.indices.last

            for (index, events) in groups.enumerated() {
                guard let firstDate = events.first?.date.startOfDay else { continue }
                let isActive = index == latestGroupIndex
                    && isMigratedLatestCycleActive(
                        events: events,
                        settings: settings,
                        today: today,
                        calendar: calendar
                    )
                let cycle = PillCycle(
                    startDate: firstDate,
                    plannedPillCount: isActive ? max(settings.pill.pillCount, 1) : nil,
                    breakDays: isActive ? max(settings.pill.pillBreakDuration, 0) : nil,
                    autoRecordEnabled: isActive ? settings.pill.pillAutoRecordEnabled : nil,
                    status: isActive ? .active : .completed
                )
                context.insert(cycle)
                events.forEach { $0.pillCycleID = cycle.id }
            }

            try context.save()
        } catch {
            assertionFailure("Pill cycle migration failed: \(error)")
        }
    }

    static func cycleInfos(in context: ModelContext) -> [PillCycleInfo] {
        do {
            let cycles = try context.fetch(
                FetchDescriptor<PillCycle>(
                    sortBy: [SortDescriptor(\PillCycle.startDate, order: .forward)]
                )
            )
            let events = try fetchPillEvents(in: context)
            let datesByCycleID = Dictionary(grouping: events.compactMap { event -> (UUID, Date)? in
                guard let cycleID = event.pillCycleID else { return nil }
                return (cycleID, event.date.startOfDay)
            }, by: { $0.0 })

            return cycles.map { cycle in
                PillCycleInfo(
                    id: cycle.id,
                    intakeDates: (datesByCycleID[cycle.id] ?? []).map { $0.1 }.sorted(),
                    plannedPillCount: cycle.plannedPillCount,
                    breakDays: cycle.breakDays,
                    autoRecordEnabled: cycle.autoRecordEnabled,
                    status: cycle.status
                )
            }
        } catch {
            assertionFailure("Pill cycle fetch failed: \(error)")
            return []
        }
    }

    static func assignCycle(
        to event: UserEvent,
        in context: ModelContext,
        settings: UserSettings,
        calendar: Calendar = .current
    ) throws {
        guard event.type == .pill, event.pillCycleID == nil else { return }

        let cycles = try context.fetch(
            FetchDescriptor<PillCycle>(
                sortBy: [SortDescriptor(\PillCycle.startDate, order: .forward)]
            )
        )
        let pillEvents = try fetchPillEvents(in: context)
        let eventsByCycleID = Dictionary(
            grouping: pillEvents.filter { $0.pillCycleID != nil },
            by: { $0.pillCycleID! }
        )
        let target = event.date.startOfDay

        let candidates = cycles.compactMap { cycle -> (cycle: PillCycle, distance: Int)? in
            let cycleEvents = eventsByCycleID[cycle.id] ?? []
            guard cycleHasCapacity(cycle, eventCount: cycleEvents.count) else { return nil }
            let dates = cycleEvents.map { $0.date.startOfDay }
            if cycle.status == .completed,
               let lastIntake = dates.max(),
               target > lastIntake {
                return nil
            }
            guard let distance = dates.map({
                abs(calendar.dateComponents([.day], from: $0, to: target).day ?? .max)
            }).min(),
                  distance <= maximumContinuityGap else {
                return nil
            }
            return (cycle, distance)
        }

        if let candidate = candidates.min(by: {
            if $0.distance == $1.distance {
                return $0.cycle.startDate > $1.cycle.startDate
            }
            return $0.distance < $1.distance
        })?.cycle {
            event.pillCycleID = candidate.id
            candidate.startDate = min(candidate.startDate.startOfDay, target)
            return
        }

        let latestExistingStart = cycles.map(\.startDate.startOfDay).max()
        let isHistoricalInsertion = latestExistingStart.map { target < $0 } ?? false
        if isHistoricalInsertion == false {
            for cycle in cycles where cycle.status == .active {
                cycle.status = .completed
            }
        }

        let cycle = PillCycle(
            startDate: target,
            plannedPillCount: isHistoricalInsertion
                ? nil
                : max(settings.pill.pillCount, 1),
            breakDays: isHistoricalInsertion
                ? nil
                : max(settings.pill.pillBreakDuration, 0),
            autoRecordEnabled: isHistoricalInsertion
                ? nil
                : settings.pill.pillAutoRecordEnabled,
            status: isHistoricalInsertion ? .completed : .active
        )
        context.insert(cycle)
        event.pillCycleID = cycle.id
    }

    static func cleanupAfterDeletion(
        cycleIDs: Set<UUID>,
        in context: ModelContext
    ) throws {
        guard cycleIDs.isEmpty == false else { return }

        let cycles = try context.fetch(FetchDescriptor<PillCycle>())
        let events = try fetchPillEvents(in: context)
        let eventsByCycleID = Dictionary(
            grouping: events.filter { $0.pillCycleID != nil },
            by: { $0.pillCycleID! }
        )

        for cycle in cycles where cycleIDs.contains(cycle.id) {
            let remaining = eventsByCycleID[cycle.id] ?? []
            if remaining.isEmpty {
                context.delete(cycle)
            } else if let first = remaining.map(\.date.startOfDay).min() {
                cycle.startDate = first
            }
        }
    }

    private static func fetchPillEvents(in context: ModelContext) throws -> [UserEvent] {
        let pillRawValue = EventType.pill.rawValue
        return try context.fetch(
            FetchDescriptor<UserEvent>(
                predicate: #Predicate { $0.typeRaw == pillRawValue },
                sortBy: [SortDescriptor(\UserEvent.date, order: .forward)]
            )
        )
    }

    private static func historicalGroups(
        events: [UserEvent],
        calendar: Calendar
    ) -> [[UserEvent]] {
        let sorted = events.sorted { $0.date.startOfDay < $1.date.startOfDay }
        guard let first = sorted.first else { return [] }

        var groups: [[UserEvent]] = [[first]]
        for event in sorted.dropFirst() {
            guard let previous = groups.last?.last else { continue }
            let gap = calendar.dateComponents(
                [.day],
                from: previous.date.startOfDay,
                to: event.date.startOfDay
            ).day ?? .max

            if gap > maximumContinuityGap {
                groups.append([event])
            } else {
                groups[groups.count - 1].append(event)
            }
        }
        return groups
    }

    private static func isMigratedLatestCycleActive(
        events: [UserEvent],
        settings: UserSettings,
        today: Date,
        calendar: Calendar
    ) -> Bool {
        guard settings.pill.pillEnabled,
              let lastIntake = events.last?.date.startOfDay else {
            return false
        }

        let pillCount = max(settings.pill.pillCount, 1)
        let projectedLastIntake: Date
        if settings.pill.pillAutoRecordEnabled {
            projectedLastIntake = lastIntake
        } else {
            let remaining = max(pillCount - events.count, 0)
            projectedLastIntake = calendar.date(
                byAdding: .day,
                value: remaining,
                to: lastIntake
            )?.startOfDay ?? lastIntake
        }

        return PillCycleCalculator.isActive(
            projectedLastIntakeDate: projectedLastIntake,
            breakDays: max(settings.pill.pillBreakDuration, 0),
            on: today,
            calendar: calendar
        )
    }

    private static func cycleHasCapacity(_ cycle: PillCycle, eventCount: Int) -> Bool {
        guard let plannedPillCount = cycle.plannedPillCount else { return true }
        return eventCount < max(plannedPillCount, 1)
    }
}
