//
//  PillCycleCalculator.swift
//  BloodyDay
//
//  Created by Yunki on 2/22/26.
//

import Foundation

enum PillCycleCalculator {
    static func groupedCycles(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [[Date]] {
        let sorted = pillDates.map { calendar.startOfDay(for: $0) }.sorted()
        guard sorted.isEmpty == false else { return [] }
        
        // Pill cycles are interpreted more strictly than the configured break length:
        // a gap of up to 4 days is still treated as the same cycle, and each cycle is
        // capped at pillCount intake dates.
        let allowedGap = min(max(breakDays, 1), 4)
        let maxCycleLength = pillCount > 0 ? pillCount : .max
        var cycles: [[Date]] = [[sorted[0]]]
        
        for day in sorted.dropFirst() {
            guard var current = cycles.last else { continue }
            guard let previous = current.last else { continue }
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? .max
            
            let shouldStartNewCycle = gap > allowedGap || current.count >= maxCycleLength
            if shouldStartNewCycle {
                cycles.append([day])
            } else {
                current.append(day)
                cycles[cycles.count - 1] = current
            }
        }
        
        return cycles
    }
    
    static func sequenceMap(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date: Int] {
        guard pillDates.isEmpty == false else { return [:] }

        if pillCycles.isEmpty == false {
            var map: [Date: Int] = [:]
            for cycle in pillCycles {
                for (index, day) in cycle.intakeDates
                    .map({ calendar.startOfDay(for: $0) })
                    .sorted()
                    .enumerated() {
                    map[day] = index + 1
                }
            }

            let assignedDates = Set(map.keys)
            let unassignedDates = pillDates.subtracting(assignedDates)
            if unassignedDates.isEmpty == false, pillCount > 0 {
                let fallback = sequenceMap(
                    pillDates: unassignedDates,
                    pillCount: pillCount,
                    breakDays: breakDays,
                    calendar: calendar
                )
                map.merge(fallback) { stored, _ in stored }
            }
            return map
        }

        guard pillCount > 0 else { return [:] }
        
        let cycles = groupedCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        
        var map: [Date: Int] = [:]
        for cycle in cycles {
            for (index, day) in cycle.enumerated() {
                map[day] = index + 1
            }
        }
        return map
    }

    static func cycleInfo(
        containing target: Date,
        pillCycles: [PillCycleInfo],
        calendar: Calendar = .autoupdatingCurrent
    ) -> PillCycleInfo? {
        let normalizedTarget = calendar.startOfDay(for: target)
        return pillCycles.first {
            $0.intakeDates
                .map { calendar.startOfDay(for: $0) }
                .contains(normalizedTarget)
        }
    }

    static func latestCycle(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date]? {
        groupedCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        ).last
    }

    static func cycle(
        containing target: Date,
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date]? {
        let normalizedTarget = calendar.startOfDay(for: target)
        return groupedCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        ).first { $0.contains(normalizedTarget) }
    }

    static func isActive(
        projectedLastIntakeDate: Date,
        breakDays: Int,
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedLastIntake = calendar.startOfDay(for: projectedLastIntakeDate)
        guard let rawExpectedNextCycleStart = calendar.date(
            byAdding: .day,
            value: max(breakDays, 0) + 1,
            to: normalizedLastIntake
        ) else {
            return false
        }
        let expectedNextCycleStart = calendar.startOfDay(for: rawExpectedNextCycleStart)

        // Keep the cycle active through its expected restart date so that the
        // first reminder for the next pack remains valid. If no new intake is
        // recorded by the following day, the old cycle no longer anchors state.
        return normalizedDate <= expectedNextCycleStart
    }
}
