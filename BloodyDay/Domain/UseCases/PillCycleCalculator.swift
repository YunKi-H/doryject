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
        calendar: Calendar = .current
    ) -> [[Date]] {
        let sorted = pillDates.map(\.startOfDay).sorted()
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
        calendar: Calendar = .current
    ) -> [Date: Int] {
        guard pillCount > 0, pillDates.isEmpty == false else { return [:] }
        
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

    static func latestCycle(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar = .current
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
        calendar: Calendar = .current
    ) -> [Date]? {
        let normalizedTarget = target.startOfDay
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
        calendar: Calendar = .current
    ) -> Bool {
        let normalizedDate = date.startOfDay
        let normalizedLastIntake = projectedLastIntakeDate.startOfDay
        guard let expectedNextCycleStart = calendar.date(
            byAdding: .day,
            value: max(breakDays, 0) + 1,
            to: normalizedLastIntake
        )?.startOfDay else {
            return false
        }

        // Keep the cycle active through its expected restart date so that the
        // first reminder for the next pack remains valid. If no new intake is
        // recorded by the following day, the old cycle no longer anchors state.
        return normalizedDate <= expectedNextCycleStart
    }
}
