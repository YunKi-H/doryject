//
//  PeriodForecastCalculator.swift
//  BloodyDay
//
//  Created by Yunki on 2/20/26.
//

import Foundation

struct PeriodPredictionContext {
    let firstExpected: Date
    let cycleLength: Int
    let predictedLength: Int
}

enum PeriodForecastCalculator {
    static func predictionContext(
        target: Date,
        settings: UserSettings,
        periodSummaries: [PeriodSummary],
        pillDates: Set<Date>,
        calendar: Calendar = .current
    ) -> PeriodPredictionContext? {
        let normalizedTarget = target.startOfDay
        let predictedLength = predictedPeriodLengthDays(settings: settings, periodSummaries: periodSummaries)
        
        if let pill = pillPredictionContext(
            target: normalizedTarget,
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        ) {
            return .init(
                firstExpected: pill.firstExpected,
                cycleLength: pill.cycleLength,
                predictedLength: predictedLength
            )
        }
        
        guard let lastStart = periodSummaries.map(\.start).max()?.startOfDay,
              let cycleLength = cycleLengthDays(settings: settings, periodSummaries: periodSummaries),
              cycleLength > 0,
              let firstExpected = calendar.date(byAdding: .day, value: cycleLength, to: lastStart)?.startOfDay else {
            return nil
        }
        
        return .init(firstExpected: firstExpected, cycleLength: cycleLength, predictedLength: predictedLength)
    }
    
    static func expectedStartDate(
        target: Date,
        today: Date = Date(),
        context: PeriodPredictionContext,
        calendar: Calendar = .current
    ) -> Date? {
        let normalizedTarget = target.startOfDay
        let normalizedToday = today.startOfDay
        
        guard context.cycleLength > 0 else { return context.firstExpected.startOfDay }
        if normalizedTarget <= context.firstExpected.startOfDay {
            return context.firstExpected.startOfDay
        }
        
        let daysFromFirst = calendar.dateComponents([.day], from: context.firstExpected.startOfDay, to: normalizedTarget).day ?? 0
        let cycleOffset = daysFromFirst / context.cycleLength
        guard let cycleStart = calendar.date(
            byAdding: .day,
            value: cycleOffset * context.cycleLength,
            to: context.firstExpected.startOfDay
        )?.startOfDay else {
            return context.firstExpected.startOfDay
        }
        
        let cycleEndExclusive = calendar.date(
            byAdding: .day,
            value: max(context.predictedLength, 1),
            to: cycleStart.startOfDay
        ) ?? cycleStart
        
        if normalizedTarget > normalizedToday && normalizedTarget >= cycleEndExclusive {
            return calendar.date(byAdding: .day, value: context.cycleLength, to: cycleStart)?.startOfDay
        }
        return cycleStart
    }
    
    static func mostRecentPillStart(
        from pillDates: Set<Date>,
        calendar: Calendar = .current
    ) -> Date? {
        guard !pillDates.isEmpty else { return nil }
        let sorted = pillDates.sorted()
        for date in sorted.reversed() {
            let previous = calendar.date(byAdding: .day, value: -1, to: date.startOfDay)!
            if !pillDates.contains(previous) {
                return date.startOfDay
            }
        }
        return sorted.first?.startOfDay
    }
    
    static func predictedPeriodLengthDays(
        settings: UserSettings,
        periodSummaries: [PeriodSummary]
    ) -> Int {
        let period = settings.period
        if period.autoCyclePredictionEnabled == false,
           let manual = period.averagePeriodDays,
           manual > 0 {
            return manual
        }
        
        let lengths = periodSummaries.map(\.lengthDays).filter { $0 > 0 }
        guard !lengths.isEmpty else { return 5 }
        let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
        return max(Int(round(avg)), 1)
    }
    
    private static func pillPredictionContext(
        target: Date,
        settings: UserSettings,
        pillDates: Set<Date>,
        calendar: Calendar
    ) -> (firstExpected: Date, cycleLength: Int)? {
        let pill = settings.pill
        guard pill.pillEnabled else { return nil }
        
        let pillCount = max(pill.pillCount, 0)
        let breakDays = max(pill.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        
        guard let anchor = mostRecentPillStart(from: pillDates, calendar: calendar),
              target >= anchor.startOfDay,
              let lastPillInCycle = calendar.date(byAdding: .day, value: pillCount - 1, to: anchor.startOfDay),
              let firstExpected = calendar.date(byAdding: .day, value: 3, to: lastPillInCycle)?.startOfDay else {
            return nil
        }
        
        return (firstExpected: firstExpected, cycleLength: cycleLength)
    }
    
    private static func cycleLengthDays(
        settings: UserSettings,
        periodSummaries: [PeriodSummary]
    ) -> Int? {
        let period = settings.period
        if period.autoCyclePredictionEnabled == false,
           let manual = period.averageCycleDays,
           manual > 0 {
            return manual
        }
        
        let cycles = periodSummaries.compactMap(\.cycleDays)
        guard !cycles.isEmpty else { return nil }
        let avg = Double(cycles.reduce(0, +)) / Double(cycles.count)
        let value = Int(round(avg))
        return value > 0 ? value : nil
    }
}
