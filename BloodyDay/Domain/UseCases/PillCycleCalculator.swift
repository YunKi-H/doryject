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
        breakDays: Int,
        calendar: Calendar = .current
    ) -> [[Date]] {
        let sorted = pillDates.map(\.startOfDay).sorted()
        guard sorted.isEmpty == false else { return [] }
        
        let allowedGap = max(breakDays, 0) + 1
        var cycles: [[Date]] = [[sorted[0]]]
        
        for day in sorted.dropFirst() {
            guard var current = cycles.last else { continue }
            guard let previous = current.last else { continue }
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? .max
            
            let shouldStartNewCycle = gap > allowedGap
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
        breakDays: Int,
        calendar: Calendar = .current
    ) -> [Date]? {
        groupedCycles(
            pillDates: pillDates,
            breakDays: breakDays,
            calendar: calendar
        ).last
    }

    static func cycle(
        containing target: Date,
        pillDates: Set<Date>,
        breakDays: Int,
        calendar: Calendar = .current
    ) -> [Date]? {
        let normalizedTarget = target.startOfDay
        return groupedCycles(
            pillDates: pillDates,
            breakDays: breakDays,
            calendar: calendar
        ).first { $0.contains(normalizedTarget) }
    }
}
