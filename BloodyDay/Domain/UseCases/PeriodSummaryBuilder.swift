//
//  PeriodSummaryBuilder.swift
//  BloodyDay
//
//  Created by Yunki on 12/13/25.
//

import Foundation

struct PeriodSummary: Identifiable {
    var id: Date { start }
    let start: Date
    let end: Date
    let lengthDays: Int
    let cycleDays: Int?
}

enum PeriodSummaryBuilder {
    static func build(
        from dates: [Date],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [PeriodSummary] {
        let normalized = Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
        guard !normalized.isEmpty else { return [] }
        
        var segments: [(start: Date, end: Date)] = []
        var currentStart = normalized[0]
        var currentEnd = normalized[0]
        
        for date in normalized.dropFirst() {
            let expectedNext = calendar.date(byAdding: .day, value: 1, to: currentEnd)!
            if calendar.isDate(date, inSameDayAs: expectedNext) {
                currentEnd = date
            } else {
                segments.append((start: currentStart, end: currentEnd))
                currentStart = date
                currentEnd = date
            }
        }
        segments.append((start: currentStart, end: currentEnd))
        
        var summaries: [PeriodSummary] = []
        for idx in segments.indices {
            let start = segments[idx].start
            let end = segments[idx].end
            let length = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            let lengthDays = max(length + 1, 1)
            let cycleDays: Int?
            if idx == 0 {
                cycleDays = nil
            } else {
                let prevStart = segments[idx - 1].start
                let cycle = calendar.dateComponents([.day], from: prevStart, to: start).day ?? 0
                cycleDays = cycle > 0 ? cycle : nil
            }
            
            summaries.append(
                PeriodSummary(
                    start: start,
                    end: end,
                    lengthDays: lengthDays,
                    cycleDays: cycleDays
                )
            )
        }
        
        return summaries
    }
}
