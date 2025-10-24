//
//  CyclePredictor.swift
//  BloodyDay
//
//  Created by Yunki on 10/21/25.
//

import Foundation

final class CyclePredictor {
    func makeRule(from cycles: [CycleRecord]) -> CycleRule? {
        guard let last = cycles.last else { return nil }
        let avgCycle = averageCycleLength(from: cycles)
        let avgPeriod = averagePeriodLength(from: cycles)
        return CycleRule(
            averageCycleLength: avgCycle,
            averagePeriodLength: avgPeriod,
            lastStartDate: last.startDate
        )
    }
    
    func predictPeriods(using rule: CycleRule, in range: DateInterval) -> [PredictedPeriod] {
        let cycle = rule.averageCycleLength
        let periodLength = rule.averagePeriodLength
        
        let daysSinceLast = Calendar.current.dateComponents([.day], from: rule.lastStartDate, to: range.start).day ?? 0
        let passedCycles = max(daysSinceLast / cycle - 1, 0)
        
        guard let firstStart = Calendar.current.date(byAdding: .day, value: passedCycles * cycle, to: rule.lastStartDate) else { return [] }
        
        var results: [PredictedPeriod] = []
        var start = firstStart
        while start <= range.end {
            let end = Calendar.current.date(byAdding: .day, value: periodLength - 1, to: start)!
            if end >= range.start {
                results.append(PredictedPeriod(startDate: start, endDate: end))
            }
            start = Calendar.current.date(byAdding: .day, value: cycle, to: start)!
        }
        
        return results
    }
    
    private func averageCycleLength(from cycles: [CycleRecord]) -> Int {
        guard cycles.count >= 2 else { return 28 }
        let intervals = zip(cycles, cycles.dropFirst()).compactMap {
            Calendar.current.dateComponents([.day], from: $0.startDate, to: $1.startDate).day
        }
        return Int(Double(intervals.reduce(0, +)) / Double(intervals.count))
    }
    
    private func averagePeriodLength(from cycles: [CycleRecord]) -> Int {
        guard !cycles.isEmpty else { return 5 }
        let lengths = cycles.map(\.periodLength)
        return Int(Double(lengths.reduce(0, +)) / Double(lengths.count))
    }
}
