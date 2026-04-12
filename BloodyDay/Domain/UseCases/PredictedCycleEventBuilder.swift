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
        let normalizedStart = rangeStart.startOfDay
        let normalizedEnd = rangeEndExclusive.startOfDay
        let normalizedToday = today.startOfDay
        let lengthDays = max(predictedLengthDays, 1)
        var predicted: [Date: [EventType]] = [:]
        
        for cycleStart in predictedPeriodStarts.map(\.startOfDay) {
            guard let cycleEndExclusive = calendar.date(byAdding: .day, value: lengthDays, to: cycleStart)?.startOfDay,
                  let ovulation = calendar.date(byAdding: .day, value: -lutealDays, to: cycleStart)?.startOfDay,
                  let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation)?.startOfDay,
                  let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation)?.startOfDay else {
                continue
            }
            
            if cycleEndExclusive <= normalizedStart {
                continue
            }
            if fertileStart >= normalizedEnd {
                continue
            }
            
            for day in Date.dates(from: cycleStart, toExclusive: cycleEndExclusive) {
                guard day >= normalizedStart && day < normalizedEnd else { continue }
                let type: EventType = day < normalizedToday ? .delayed : .period
                predicted[day, default: []].append(type)
            }
            
            for day in Date.dates(from: fertileStart, to: fertileEnd) {
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
