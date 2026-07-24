//
//  PredictedCycleEventBuilder.swift
//  BloodyDay
//
//  Created by Yunki on 4/12/26.
//

import Foundation

enum PredictedCycleEventBuilder {
    static func buildEvents(
        predictedPeriodStarts: [Date],
        rangeStart: Date,
        rangeEndExclusive: Date,
        predictedLengthDays: Int,
        today: Date,
        lutealDays: Int = 14,
        calendar: Calendar = .current
    ) -> [Date: [EventType]] {
        let normalizedStart = calendar.startOfDay(for: rangeStart)
        let normalizedEnd = calendar.startOfDay(for: rangeEndExclusive)
        let normalizedToday = calendar.startOfDay(for: today)
        let lengthDays = max(predictedLengthDays, 1)
        var predicted: [Date: [EventType]] = [:]
        
        for rawCycleStart in predictedPeriodStarts {
            let cycleStart = calendar.startOfDay(for: rawCycleStart)
            guard let rawCycleEndExclusive = calendar.date(byAdding: .day, value: lengthDays, to: cycleStart),
                  let rawOvulation = calendar.date(byAdding: .day, value: -lutealDays, to: cycleStart) else {
                continue
            }
            let cycleEndExclusive = calendar.startOfDay(for: rawCycleEndExclusive)
            let ovulation = calendar.startOfDay(for: rawOvulation)
            guard let rawFertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation),
                  let rawFertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation) else {
                continue
            }
            let fertileStart = calendar.startOfDay(for: rawFertileStart)
            let fertileEnd = calendar.startOfDay(for: rawFertileEnd)
            
            if cycleEndExclusive <= normalizedStart {
                continue
            }
            if fertileStart >= normalizedEnd {
                continue
            }
            
            for day in Date.dates(
                from: cycleStart,
                toExclusive: cycleEndExclusive,
                calendar: calendar
            ) {
                guard day >= normalizedStart && day < normalizedEnd else { continue }
                let type: EventType = day < normalizedToday ? .delayed : .period
                predicted[day, default: []].append(type)
            }
            
            for day in Date.dates(
                from: fertileStart,
                to: fertileEnd,
                calendar: calendar
            ) {
                guard day >= normalizedStart && day < normalizedEnd else { continue }
                predicted[day, default: []].append(.fertile)
            }
            
            if ovulation >= normalizedStart && ovulation < normalizedEnd {
                predicted[ovulation, default: []].append(.ovulation)
            }
        }
        
        return predicted.mapValues { uniqueEventTypes(in: $0) }
    }
    
    private static func uniqueEventTypes(in events: [EventType]) -> [EventType] {
        var seen: Set<EventType> = []
        var unique: [EventType] = []
        for event in events where !seen.contains(event) {
            unique.append(event)
            seen.insert(event)
        }
        return unique
    }
}
