//
//  CyclePrediction.swift
//  BloodyDay
//
//  Created by Codex.
//

import Foundation

struct CyclePredictionResult {
    let predictedEventsByDay: [Date: [EventType]]
}

enum CyclePrediction {
    static func predictEvents(
        periodEvents: [UserEvent],
        rangeStart: Date,
        rangeEndExclusive: Date,
        avgCycleDays: Int? = nil,
        avgPeriodDays: Int? = nil,
        lutealDays: Int = 14,
        calendar: Calendar = .current
    ) -> CyclePredictionResult {
        let normalizedRangeStart = rangeStart.startOfDay
        let normalizedRangeEnd = rangeEndExclusive.startOfDay
        
        let periodDates = periodEvents.map { $0.date.startOfDay }
        let segments = buildPeriodSegments(from: periodDates, calendar: calendar)
        guard let lastStart = segments.last?.start else {
            return .init(predictedEventsByDay: [:])
        }
        
        let computedCycle = avgCycleDays ?? averageCycleDays(from: segments, calendar: calendar)
        let computedPeriod = avgPeriodDays ?? averagePeriodDays(from: segments)
        
        guard let cycleDays = computedCycle, let periodDays = computedPeriod else {
            return .init(predictedEventsByDay: [:])
        }
        
        var predicted: [Date: [EventType]] = [:]
        let today = Date().startOfDay
        var nextStart = calendar.date(byAdding: .day, value: cycleDays, to: lastStart.startOfDay)!
        
        while nextStart < normalizedRangeEnd {
            let periodEndExclusive = calendar.date(byAdding: .day, value: periodDays, to: nextStart)!
            for day in Date.dates(from: nextStart, toExclusive: periodEndExclusive) {
                if day >= normalizedRangeStart && day < normalizedRangeEnd {
                    let periodType: EventType = day < today ? .delayed : .period
                    predicted[day, default: []].append(periodType)
                }
            }
            
            let ovulation = calendar.date(byAdding: .day, value: -lutealDays, to: nextStart)!.startOfDay
            let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation)!.startOfDay
            let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation)!.startOfDay
            
            for day in Date.dates(from: fertileStart, to: fertileEnd) {
                if day >= normalizedRangeStart && day < normalizedRangeEnd {
                    predicted[day, default: []].append(.fertile)
                }
            }
            
            if ovulation >= normalizedRangeStart && ovulation < normalizedRangeEnd {
                predicted[ovulation, default: []].append(.ovulation)
            }
            
            nextStart = calendar.date(byAdding: .day, value: cycleDays, to: nextStart)!
        }
        
        return .init(predictedEventsByDay: predicted.mapValues { uniqueEventTypes(in: $0) })
    }
    
    private static func buildPeriodSegments(
        from dates: [Date],
        calendar: Calendar
    ) -> [(start: Date, length: Int)] {
        let uniqueSorted = Array(Set(dates.map { $0.startOfDay })).sorted()
        guard !uniqueSorted.isEmpty else { return [] }
        
        var segments: [(start: Date, length: Int)] = []
        var currentStart = uniqueSorted[0]
        var currentLength = 1
        var previous = uniqueSorted[0]
        
        for date in uniqueSorted.dropFirst() {
            let expectedNext = calendar.date(byAdding: .day, value: 1, to: previous)!
            if calendar.isDate(date, inSameDayAs: expectedNext) {
                currentLength += 1
            } else {
                segments.append((start: currentStart, length: currentLength))
                currentStart = date
                currentLength = 1
            }
            previous = date
        }
        
        segments.append((start: currentStart, length: currentLength))
        return segments
    }
    
    private static func averageCycleDays(
        from segments: [(start: Date, length: Int)],
        calendar: Calendar
    ) -> Int? {
        guard segments.count >= 2 else { return nil }
        let starts = segments.map(\.start).sorted()
        var diffs: [Int] = []
        for (prev, next) in zip(starts, starts.dropFirst()) {
            let days = calendar.dateComponents([.day], from: prev, to: next).day ?? 0
            if days > 0 { diffs.append(days) }
        }
        guard !diffs.isEmpty else { return nil }
        let avg = Double(diffs.reduce(0, +)) / Double(diffs.count)
        return Int(round(avg))
    }
    
    private static func averagePeriodDays(
        from segments: [(start: Date, length: Int)]
    ) -> Int? {
        guard !segments.isEmpty else { return nil }
        let lengths = segments.map(\.length).filter { $0 > 0 }
        guard !lengths.isEmpty else { return nil }
        let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
        return Int(round(avg))
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
