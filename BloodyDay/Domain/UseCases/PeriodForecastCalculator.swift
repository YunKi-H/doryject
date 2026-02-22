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

struct PillCycleProjection {
    let cycleStart: Date
    let lastIntakeDate: Date
    let intakeCount: Int
    let projectedLastIntakeDate: Date
    let pillCount: Int
    let breakDays: Int
    
    var cycleLength: Int { pillCount + breakDays }
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
        guard pillDates.isEmpty == false else { return nil }
        let sorted = pillDates.map(\.startOfDay).sorted()
        for date in sorted.reversed() {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date.startOfDay)?.startOfDay else {
                continue
            }
            if pillDates.contains(previous) == false {
                return date.startOfDay
            }
        }
        return sorted.first?.startOfDay
    }
    
    static func pillSequenceMap(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar = .current
    ) -> [Date: Int] {
        PillCycleCalculator.sequenceMap(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
    }
    
    static func latestPillCycleProjection(
        settings: UserSettings,
        pillDates: Set<Date>,
        calendar: Calendar = .current
    ) -> PillCycleProjection? {
        let pill = settings.pill
        guard pill.pillEnabled else { return nil }
        let pillCount = max(pill.pillCount, 0)
        let breakDays = max(pill.pillBreakDuration, 0)
        guard pillCount > 0 else { return nil }
        
        if pill.pillAutoRecordEnabled {
            guard let latestCycle = PillCycleCalculator.groupedCycles(
                pillDates: pillDates,
                breakDays: breakDays,
                calendar: calendar
            ).last,
                  let cycleStart = latestCycle.first,
                  let lastIntake = latestCycle.last else {
                return nil
            }
            
            let intakeCount = min(latestCycle.count, pillCount)
            let projectedLast = lastIntake.startOfDay
            
            return PillCycleProjection(
                cycleStart: cycleStart.startOfDay,
                lastIntakeDate: lastIntake.startOfDay,
                intakeCount: intakeCount,
                projectedLastIntakeDate: projectedLast,
                pillCount: pillCount,
                breakDays: breakDays
            )
        }
        
        // Auto record OFF: continue current cycle by intake count progression.
        guard let latestCycle = PillCycleCalculator.groupedCycles(
            pillDates: pillDates,
            breakDays: breakDays,
            calendar: calendar
        ).last,
              let cycleStart = latestCycle.first,
              let lastIntake = latestCycle.last else {
            return nil
        }
        let intakeCount = min(latestCycle.count, pillCount)
        let remaining = max(pillCount - intakeCount, 0)
        guard let projectedLast = calendar.date(
            byAdding: .day,
            value: remaining,
            to: lastIntake.startOfDay
        )?.startOfDay else {
            return nil
        }
        return PillCycleProjection(
            cycleStart: cycleStart.startOfDay,
            lastIntakeDate: lastIntake.startOfDay,
            intakeCount: intakeCount,
            projectedLastIntakeDate: projectedLast,
            pillCount: pillCount,
            breakDays: breakDays
        )
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
        guard let projection = latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        ) else {
            return nil
        }
        guard target >= projection.cycleStart else { return nil }
        guard let firstExpected = calendar.date(byAdding: .day, value: 3, to: projection.projectedLastIntakeDate)?.startOfDay else {
            return nil
        }
        
        return (firstExpected: firstExpected, cycleLength: projection.cycleLength)
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
