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
        let latestActualStart = periodSummaries.map(\.start).max()?.startOfDay
        let actualCycleLength = cycleLengthDays(settings: settings, periodSummaries: periodSummaries)
        
        if let projection = latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        ),
           normalizedTarget >= projection.cycleStart.startOfDay,
           let latestActualStart,
           latestActualStart >= projection.cycleStart.startOfDay,
           normalizedTarget >= latestActualStart,
           let actualCycleLength,
           actualCycleLength > 0,
           let firstExpectedFromActual = calendar.date(byAdding: .day, value: actualCycleLength, to: latestActualStart)?.startOfDay {
            return .init(
                firstExpected: firstExpectedFromActual,
                cycleLength: actualCycleLength,
                predictedLength: predictedLength
            )
        }
        
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
        
        guard let latestActualStart,
              let actualCycleLength,
              actualCycleLength > 0,
              let firstExpected = calendar.date(byAdding: .day, value: actualCycleLength, to: latestActualStart)?.startOfDay else {
            return nil
        }
        
        return .init(firstExpected: firstExpected, cycleLength: actualCycleLength, predictedLength: predictedLength)
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

    static func delayedPeriodStart(
        for date: Date,
        predictedStarts: [Date],
        predictedLength: Int,
        calendar: Calendar = .current
    ) -> Date? {
        let target = date.startOfDay
        let length = max(predictedLength, 1)

        return predictedStarts
            .map(\.startOfDay)
            .filter { start in
                guard let endExclusive = calendar.date(
                    byAdding: .day,
                    value: length,
                    to: start
                )?.startOfDay else {
                    return false
                }
                return endExclusive <= target
            }
            .max()
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
            guard let latestCycle = PillCycleCalculator.latestCycle(
                pillDates: pillDates,
                pillCount: pillCount,
                breakDays: breakDays,
                calendar: calendar
            ),
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
        guard let latestCycle = PillCycleCalculator.latestCycle(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        ),
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

    static func suppressPredictedCycleArtifactsOverlappingActualPeriods(
        predictedEventsByDay: inout [Date: [EventType]],
        actualPeriodSummaries: [PeriodSummary],
        estimatedCycleLength: Int?,
        calendar: Calendar = .current
    ) {
        let actualPeriodDates = actualPeriodDateSet(from: actualPeriodSummaries)
        guard actualPeriodDates.isEmpty == false, predictedEventsByDay.isEmpty == false else { return }

        let runs = predictedPeriodRuns(from: predictedEventsByDay, calendar: calendar)
        guard runs.isEmpty == false else { return }

        var runStartDatesToRemove: Set<Date> = []

        for run in runs where run.dates.contains(where: { actualPeriodDates.contains($0) }) {
            runStartDatesToRemove.insert(run.start)
        }

        let actualStarts = actualPeriodSummaries.map { $0.start.startOfDay }.sorted()
        if actualStarts.isEmpty == false {
            let cycle = max(estimatedCycleLength ?? 0, 0)
            let toleranceDays = max(min(cycle > 0 ? cycle / 2 : 7, 14), 3)
            var availableRuns = runs.filter { !runStartDatesToRemove.contains($0.start) }

            for actualStart in actualStarts {
                guard let bestIndex = availableRuns.enumerated()
                    .map({ (index: $0.offset, run: $0.element) })
                    .min(by: {
                        abs((calendar.dateComponents([.day], from: $0.run.start, to: actualStart).day ?? .max))
                        < abs((calendar.dateComponents([.day], from: $1.run.start, to: actualStart).day ?? .max))
                    })?.index else {
                    continue
                }

                let candidate = availableRuns[bestIndex]
                let distance = abs(calendar.dateComponents([.day], from: candidate.start, to: actualStart).day ?? .max)
                guard distance <= toleranceDays else { continue }

                runStartDatesToRemove.insert(candidate.start)
                availableRuns.remove(at: bestIndex)
            }
        }

        guard runStartDatesToRemove.isEmpty == false else { return }
        removePredictedFertilityForRemovedPeriodRuns(
            predictedEventsByDay: &predictedEventsByDay,
            removedRunStarts: runStartDatesToRemove,
            estimatedCycleLength: estimatedCycleLength,
            calendar: calendar
        )

        for run in runs where runStartDatesToRemove.contains(run.start) {
            for date in run.dates {
                guard var types = predictedEventsByDay[date] else { continue }
                types.removeAll { $0 == .period || $0 == .delayed }
                predictedEventsByDay[date] = types
            }
        }
    }

    static func validPredictedPeriodStarts(
        rawStarts: [Date],
        today: Date,
        predictedLength: Int,
        actualPeriodSummaries: [PeriodSummary],
        estimatedCycleLength: Int?,
        calendar: Calendar = .current
    ) -> [Date] {
        guard rawStarts.isEmpty == false else { return [] }

        var predictedEventsByDay: [Date: [EventType]] = [:]
        let normalizedToday = today.startOfDay
        let length = max(predictedLength, 1)

        for start in rawStarts.map(\.startOfDay) {
            guard let endExclusive = calendar.date(byAdding: .day, value: length, to: start)?.startOfDay else {
                continue
            }
            for day in Date.dates(from: start, toExclusive: endExclusive) {
                let type: EventType = day < normalizedToday ? .delayed : .period
                predictedEventsByDay[day.startOfDay, default: []].append(type)
            }
        }

        predictedEventsByDay = predictedEventsByDay.mapValues { types in
            var seen: Set<EventType> = []
            var unique: [EventType] = []
            for type in types where !seen.contains(type) {
                seen.insert(type)
                unique.append(type)
            }
            return unique
        }

        suppressPredictedCycleArtifactsOverlappingActualPeriods(
            predictedEventsByDay: &predictedEventsByDay,
            actualPeriodSummaries: actualPeriodSummaries,
            estimatedCycleLength: estimatedCycleLength,
            calendar: calendar
        )

        return predictedPeriodRuns(from: predictedEventsByDay, calendar: calendar)
            .map(\.start)
            .sorted()
    }
    
    static func predictedPeriodStarts(
        rangeStart: Date,
        rangeEndExclusive: Date,
        today: Date,
        settings: UserSettings,
        periodSummaries: [PeriodSummary],
        pillDates: Set<Date>,
        calendar: Calendar = .current
    ) -> [Date] {
        let normalizedToday = today.startOfDay
        guard let context = predictionContext(
            target: normalizedToday,
            settings: settings,
            periodSummaries: periodSummaries,
            pillDates: pillDates,
            calendar: calendar
        ) else {
            return []
        }
        
        let rawStarts = rawPredictedPeriodStarts(
            rangeStart: rangeStart,
            rangeEndExclusive: rangeEndExclusive,
            today: normalizedToday,
            context: context,
            calendar: calendar
        )
        guard rawStarts.isEmpty == false else { return [] }
        
        return validPredictedPeriodStarts(
            rawStarts: rawStarts,
            today: normalizedToday,
            predictedLength: context.predictedLength,
            actualPeriodSummaries: periodSummaries,
            estimatedCycleLength: context.cycleLength,
            calendar: calendar
        )
        .filter { start in
            guard let endExclusive = calendar.date(
                byAdding: .day,
                value: max(context.predictedLength, 1),
                to: start.startOfDay
            )?.startOfDay else {
                return false
            }
            return endExclusive > rangeStart.startOfDay && start.startOfDay < rangeEndExclusive.startOfDay
        }
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
    
    private static func rawPredictedPeriodStarts(
        rangeStart: Date,
        rangeEndExclusive: Date,
        today: Date,
        context: PeriodPredictionContext,
        calendar: Calendar
    ) -> [Date] {
        guard let currentOrContaining = expectedStartDate(
            target: today,
            today: today,
            context: context,
            calendar: calendar
        )?.startOfDay else {
            return []
        }
        
        var rawStarts: [Date] = []
        var cursor = currentOrContaining
        if let previous = calendar.date(
            byAdding: .day,
            value: -context.cycleLength,
            to: currentOrContaining
        )?.startOfDay {
            rawStarts.append(previous)
        }
        rawStarts.append(cursor)
        
        guard context.cycleLength > 0 else { return rawStarts }
        while let following = calendar.date(byAdding: .day, value: context.cycleLength, to: cursor)?.startOfDay {
            if following >= rangeEndExclusive.startOfDay {
                break
            }
            rawStarts.append(following)
            cursor = following
        }
        return rawStarts.filter { start in
            guard let endExclusive = calendar.date(
                byAdding: .day,
                value: max(context.predictedLength, 1),
                to: start.startOfDay
            )?.startOfDay else {
                return false
            }
            return endExclusive > rangeStart.startOfDay && start.startOfDay < rangeEndExclusive.startOfDay
        }
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

    private struct PredictedPeriodRun {
        let start: Date
        let dates: [Date]
    }

    private static func actualPeriodDateSet(from summaries: [PeriodSummary]) -> Set<Date> {
        var dates: Set<Date> = []
        for summary in summaries {
            for day in Date.dates(from: summary.start.startOfDay, to: summary.end.startOfDay) {
                dates.insert(day.startOfDay)
            }
        }
        return dates
    }

    private static func predictedPeriodRuns(
        from predictedEventsByDay: [Date: [EventType]],
        calendar: Calendar
    ) -> [PredictedPeriodRun] {
        let predictedPeriodLikeDates = predictedEventsByDay.keys
            .map(\.startOfDay)
            .filter { key in
                guard let types = predictedEventsByDay[key] else { return false }
                return types.contains(.period) || types.contains(.delayed)
            }
            .sorted()

        guard predictedPeriodLikeDates.isEmpty == false else { return [] }

        var runs: [PredictedPeriodRun] = []
        var currentRun: [Date] = []
        for date in predictedPeriodLikeDates {
            if let previous = currentRun.last {
                let gap = calendar.dateComponents([.day], from: previous, to: date).day ?? .max
                if gap == 1 {
                    currentRun.append(date)
                } else {
                    if let first = currentRun.first {
                        runs.append(PredictedPeriodRun(start: first, dates: currentRun))
                    }
                    currentRun.removeAll(keepingCapacity: true)
                    currentRun.append(date)
                }
            } else {
                currentRun.append(date)
            }
        }
        if let first = currentRun.first {
            runs.append(PredictedPeriodRun(start: first, dates: currentRun))
        }
        return runs
    }

    private static func removePredictedFertilityForRemovedPeriodRuns(
        predictedEventsByDay: inout [Date: [EventType]],
        removedRunStarts: Set<Date>,
        estimatedCycleLength: Int?,
        calendar: Calendar
    ) {
        guard removedRunStarts.isEmpty == false else { return }

        let cycleLength = estimatedCycleLength ?? 0
        let lutealDays = 14

        for periodStart in removedRunStarts {
            let ovulationDate = calendar.date(byAdding: .day, value: -lutealDays, to: periodStart)?.startOfDay
            if let ovulationDate,
               var ovulationTypes = predictedEventsByDay[ovulationDate] {
                ovulationTypes.removeAll { $0 == .ovulation }
                predictedEventsByDay[ovulationDate] = ovulationTypes
            }

            if let fertileStart = ovulationDate.flatMap({ calendar.date(byAdding: .day, value: -5, to: $0) })?.startOfDay,
               let fertileEnd = ovulationDate.flatMap({ calendar.date(byAdding: .day, value: 1, to: $0) })?.startOfDay {
                for day in Date.dates(from: fertileStart, to: fertileEnd) {
                    guard var types = predictedEventsByDay[day.startOfDay] else { continue }
                    types.removeAll { $0 == .fertile }
                    predictedEventsByDay[day.startOfDay] = types
                }
            }

            guard cycleLength > 0,
                  let nextPeriodStart = calendar.date(byAdding: .day, value: cycleLength, to: periodStart)?.startOfDay else {
                continue
            }
            for date in Array(predictedEventsByDay.keys) {
                let day = date.startOfDay
                guard day >= periodStart && day < nextPeriodStart else { continue }
                guard var types = predictedEventsByDay[date] else { continue }
                let beforeCount = types.count
                types.removeAll { $0 == .fertile || $0 == .ovulation }
                if types.count != beforeCount {
                    predictedEventsByDay[date] = types
                }
            }
        }
    }
    
}
