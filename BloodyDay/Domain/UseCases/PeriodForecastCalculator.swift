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
    let subsequentCycleLength: Int?

    init(
        firstExpected: Date,
        cycleLength: Int,
        predictedLength: Int,
        subsequentCycleLength: Int? = nil
    ) {
        self.firstExpected = firstExpected
        self.cycleLength = cycleLength
        self.predictedLength = predictedLength
        self.subsequentCycleLength = subsequentCycleLength
    }

    var recurringCycleLength: Int {
        max(subsequentCycleLength ?? cycleLength, 1)
    }
}

struct PillCycleProjection {
    let cycleStart: Date
    let lastIntakeDate: Date
    let intakeCount: Int
    let projectedLastIntakeDate: Date
    let pillCount: Int
    let breakDays: Int
    
    var cycleLength: Int { pillCount + breakDays }

    func activeDateRange(
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval? {
        let normalizedStart = calendar.startOfDay(for: cycleStart)
        let normalizedLastIntake = calendar.startOfDay(for: projectedLastIntakeDate)
        guard let rawEndExclusive = calendar.date(
            byAdding: .day,
            value: max(breakDays, 0) + 1,
            to: normalizedLastIntake
        ) else {
            return nil
        }
        let endExclusive = calendar.startOfDay(for: rawEndExclusive)
        guard endExclusive > normalizedStart else { return nil }
        return DateInterval(
            start: normalizedStart,
            end: endExclusive
        )
    }
}

enum PeriodForecastCalculator {
    static func predictionContext(
        target: Date,
        settings: UserSettings,
        periodSummaries: [PeriodSummary],
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> PeriodPredictionContext? {
        let normalizedTarget = calendar.startOfDay(for: target)
        let predictedLength = predictedPeriodLengthDays(settings: settings, periodSummaries: periodSummaries)
        let latestActualStart = periodSummaries
            .map { calendar.startOfDay(for: $0.start) }
            .max()
        let actualCycleLength = cycleLengthDays(settings: settings, periodSummaries: periodSummaries)
        
        if let projection = activePillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            pillCycles: pillCycles,
            on: normalizedTarget,
            calendar: calendar
        ),
           normalizedTarget >= calendar.startOfDay(for: projection.cycleStart),
           let latestActualStart,
           latestActualStart >= calendar.startOfDay(for: projection.cycleStart),
           normalizedTarget >= latestActualStart,
           let actualCycleLength,
           actualCycleLength > 0,
           let rawFirstExpectedFromActual = calendar.date(
            byAdding: .day,
            value: actualCycleLength,
            to: latestActualStart
           ) {
            return .init(
                firstExpected: calendar.startOfDay(for: rawFirstExpectedFromActual),
                cycleLength: actualCycleLength,
                predictedLength: predictedLength
            )
        }
        
        if let pill = pillPredictionContext(
            target: normalizedTarget,
            settings: settings,
            pillDates: pillDates,
            pillCycles: pillCycles,
            calendar: calendar
        ) {
            return .init(
                firstExpected: pill.firstExpected,
                cycleLength: pill.cycleLength,
                predictedLength: predictedLength,
                subsequentCycleLength: pill.subsequentCycleLength
            )
        }
        
        guard let latestActualStart,
              let actualCycleLength,
              actualCycleLength > 0,
              let rawFirstExpected = calendar.date(
                byAdding: .day,
                value: actualCycleLength,
                to: latestActualStart
              ) else {
            return nil
        }
        
        return .init(
            firstExpected: calendar.startOfDay(for: rawFirstExpected),
            cycleLength: actualCycleLength,
            predictedLength: predictedLength
        )
    }
    
    static func expectedStartDate(
        target: Date,
        today: Date = Date(),
        context: PeriodPredictionContext,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let normalizedTarget = calendar.startOfDay(for: target)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedFirstExpected = calendar.startOfDay(for: context.firstExpected)
        
        guard context.cycleLength > 0 else { return normalizedFirstExpected }
        if normalizedTarget <= normalizedFirstExpected {
            return normalizedFirstExpected
        }
        
        let daysFromFirst = calendar.dateComponents(
            [.day],
            from: normalizedFirstExpected,
            to: normalizedTarget
        ).day ?? 0
        let recurringCycleLength = context.recurringCycleLength
        let cycleOffset = daysFromFirst / recurringCycleLength
        guard let cycleStart = calendar.date(
            byAdding: .day,
            value: cycleOffset * recurringCycleLength,
            to: normalizedFirstExpected
        ) else {
            return normalizedFirstExpected
        }
        let normalizedCycleStart = calendar.startOfDay(for: cycleStart)
        
        let cycleEndExclusive = calendar.date(
            byAdding: .day,
            value: max(context.predictedLength, 1),
            to: normalizedCycleStart
        ) ?? normalizedCycleStart
        
        if normalizedTarget > normalizedToday && normalizedTarget >= cycleEndExclusive {
            return calendar.date(
                byAdding: .day,
                value: recurringCycleLength,
                to: normalizedCycleStart
            ).map { calendar.startOfDay(for: $0) }
        }
        return normalizedCycleStart
    }

    static func delayedPeriodStart(
        for date: Date,
        predictedStarts: [Date],
        predictedLength: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let target = calendar.startOfDay(for: date)
        let length = max(predictedLength, 1)

        return predictedStarts
            .map { calendar.startOfDay(for: $0) }
            .filter { start in
                guard let endExclusive = calendar.date(
                    byAdding: .day,
                    value: length,
                    to: start
                ) else {
                    return false
                }
                return calendar.startOfDay(for: endExclusive) <= target
            }
            .max()
    }
    
    static func mostRecentPillStart(
        from pillDates: Set<Date>,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        guard pillDates.isEmpty == false else { return nil }
        let normalizedPillDates = Set(
            pillDates.map { calendar.startOfDay(for: $0) }
        )
        let sorted = normalizedPillDates.sorted()
        for date in sorted.reversed() {
            guard let rawPrevious = calendar.date(
                byAdding: .day,
                value: -1,
                to: date
            ) else {
                continue
            }
            let previous = calendar.startOfDay(for: rawPrevious)
            if normalizedPillDates.contains(previous) == false {
                return date
            }
        }
        return sorted.first
    }
    
    static func pillSequenceMap(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date: Int] {
        PillCycleCalculator.sequenceMap(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            pillCycles: pillCycles,
            calendar: calendar
        )
    }
    
    static func latestPillCycleProjection(
        settings: UserSettings,
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> PillCycleProjection? {
        let pill = settings.pill
        guard pill.pillEnabled else { return nil }

        if pillCycles.isEmpty == false {
            guard let cycle = pillCycles
                .filter({ $0.status == .active })
                .max(by: {
                    ($0.startDate(calendar: calendar) ?? .distantPast)
                        < ($1.startDate(calendar: calendar) ?? .distantPast)
                }),
                  let cycleStart = cycle.startDate(calendar: calendar),
                  let lastIntake = cycle.lastIntakeDate(calendar: calendar),
                  let storedPillCount = cycle.plannedPillCount,
                  storedPillCount > 0 else {
                return nil
            }

            let storedBreakDays = max(cycle.breakDays ?? 0, 0)
            let intakeCount = cycle.intakeDates.count
            let projectedLast: Date
            if cycle.autoRecordEnabled ?? true {
                projectedLast = lastIntake
            } else {
                let remaining = max(storedPillCount - intakeCount, 0)
                projectedLast = calendar.date(
                    byAdding: .day,
                    value: remaining,
                    to: lastIntake
                ).map { calendar.startOfDay(for: $0) }
                    ?? calendar.startOfDay(for: lastIntake)
            }

            return PillCycleProjection(
                cycleStart: cycleStart,
                lastIntakeDate: lastIntake,
                intakeCount: intakeCount,
                projectedLastIntakeDate: projectedLast,
                pillCount: storedPillCount,
                breakDays: storedBreakDays
            )
        }

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
            let projectedLast = calendar.startOfDay(for: lastIntake)
            
            return PillCycleProjection(
                cycleStart: calendar.startOfDay(for: cycleStart),
                lastIntakeDate: calendar.startOfDay(for: lastIntake),
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
            to: calendar.startOfDay(for: lastIntake)
        ) else {
            return nil
        }
        return PillCycleProjection(
            cycleStart: calendar.startOfDay(for: cycleStart),
            lastIntakeDate: calendar.startOfDay(for: lastIntake),
            intakeCount: intakeCount,
            projectedLastIntakeDate: calendar.startOfDay(for: projectedLast),
            pillCount: pillCount,
            breakDays: breakDays
        )
    }

    static func activePillCycleProjection(
        settings: UserSettings,
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo] = [],
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> PillCycleProjection? {
        guard let projection = latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            pillCycles: pillCycles,
            calendar: calendar
        ),
              PillCycleCalculator.isActive(
                projectedLastIntakeDate: projection.projectedLastIntakeDate,
                breakDays: projection.breakDays,
                on: date,
                calendar: calendar
              ) else {
            return nil
        }
        return projection
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
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let actualPeriodDates = actualPeriodDateSet(
            from: actualPeriodSummaries,
            calendar: calendar
        )
        guard actualPeriodDates.isEmpty == false, predictedEventsByDay.isEmpty == false else { return }

        let runs = predictedPeriodRuns(from: predictedEventsByDay, calendar: calendar)
        guard runs.isEmpty == false else { return }

        var runStartDatesToRemove: Set<Date> = []

        for run in runs where run.dates.contains(where: { actualPeriodDates.contains($0) }) {
            runStartDatesToRemove.insert(run.start)
        }

        let actualStarts = actualPeriodSummaries
            .map { calendar.startOfDay(for: $0.start) }
            .sorted()
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
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date] {
        guard rawStarts.isEmpty == false else { return [] }

        var predictedEventsByDay: [Date: [EventType]] = [:]
        let normalizedToday = calendar.startOfDay(for: today)
        let length = max(predictedLength, 1)

        for rawStart in rawStarts {
            let start = calendar.startOfDay(for: rawStart)
            guard let rawEndExclusive = calendar.date(
                byAdding: .day,
                value: length,
                to: start
            ) else {
                continue
            }
            let endExclusive = calendar.startOfDay(for: rawEndExclusive)
            for day in Date.dates(
                from: start,
                toExclusive: endExclusive,
                calendar: calendar
            ) {
                let type: EventType = day < normalizedToday ? .delayed : .period
                predictedEventsByDay[
                    calendar.startOfDay(for: day),
                    default: []
                ].append(type)
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
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date] {
        let normalizedToday = calendar.startOfDay(for: today)
        guard let context = predictionContext(
            target: normalizedToday,
            settings: settings,
            periodSummaries: periodSummaries,
            pillDates: pillDates,
            pillCycles: pillCycles,
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
            estimatedCycleLength: context.recurringCycleLength,
            calendar: calendar
        )
        .filter { start in
            guard let endExclusive = calendar.date(
                byAdding: .day,
                value: max(context.predictedLength, 1),
                to: calendar.startOfDay(for: start)
            ) else {
                return false
            }
            return calendar.startOfDay(for: endExclusive)
                > calendar.startOfDay(for: rangeStart)
                && calendar.startOfDay(for: start)
                < calendar.startOfDay(for: rangeEndExclusive)
        }
    }
    
    private static func pillPredictionContext(
        target: Date,
        settings: UserSettings,
        pillDates: Set<Date>,
        pillCycles: [PillCycleInfo],
        calendar: Calendar
    ) -> (
        firstExpected: Date,
        cycleLength: Int,
        subsequentCycleLength: Int
    )? {
        guard let projection = activePillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            pillCycles: pillCycles,
            on: target,
            calendar: calendar
        ) else {
            return nil
        }
        guard target >= projection.cycleStart else { return nil }
        guard let rawFirstExpected = calendar.date(
            byAdding: .day,
            value: 3,
            to: projection.projectedLastIntakeDate
        ) else {
            return nil
        }
        let firstExpected = calendar.startOfDay(for: rawFirstExpected)
        
        let futureCycleLength = max(
            settings.pill.pillCount + settings.pill.pillBreakDuration,
            1
        )
        return (
            firstExpected: firstExpected,
            cycleLength: projection.cycleLength,
            subsequentCycleLength: futureCycleLength
        )
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
        ).map({ calendar.startOfDay(for: $0) }) else {
            return []
        }
        
        var rawStarts: [Date] = []
        var cursor = currentOrContaining
        if let previous = calendar.date(
            byAdding: .day,
            value: -context.recurringCycleLength,
            to: currentOrContaining
        ) {
            rawStarts.append(calendar.startOfDay(for: previous))
        }
        rawStarts.append(cursor)
        
        guard context.recurringCycleLength > 0 else { return rawStarts }
        while let following = calendar.date(
            byAdding: .day,
            value: context.recurringCycleLength,
            to: cursor
        ) {
            let normalizedFollowing = calendar.startOfDay(for: following)
            if normalizedFollowing >= calendar.startOfDay(for: rangeEndExclusive) {
                break
            }
            rawStarts.append(normalizedFollowing)
            cursor = normalizedFollowing
        }
        return rawStarts.filter { start in
            guard let endExclusive = calendar.date(
                byAdding: .day,
                value: max(context.predictedLength, 1),
                to: calendar.startOfDay(for: start)
            ) else {
                return false
            }
            return calendar.startOfDay(for: endExclusive)
                > calendar.startOfDay(for: rangeStart)
                && calendar.startOfDay(for: start)
                < calendar.startOfDay(for: rangeEndExclusive)
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

    private static func actualPeriodDateSet(
        from summaries: [PeriodSummary],
        calendar: Calendar
    ) -> Set<Date> {
        var dates: Set<Date> = []
        for summary in summaries {
            for day in Date.dates(
                from: calendar.startOfDay(for: summary.start),
                to: calendar.startOfDay(for: summary.end),
                calendar: calendar
            ) {
                dates.insert(calendar.startOfDay(for: day))
            }
        }
        return dates
    }

    private static func predictedPeriodRuns(
        from predictedEventsByDay: [Date: [EventType]],
        calendar: Calendar
    ) -> [PredictedPeriodRun] {
        let predictedPeriodLikeDates = predictedEventsByDay.keys
            .map { calendar.startOfDay(for: $0) }
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
            let ovulationDate = calendar.date(
                byAdding: .day,
                value: -lutealDays,
                to: periodStart
            ).map { calendar.startOfDay(for: $0) }
            if let ovulationDate,
               var ovulationTypes = predictedEventsByDay[ovulationDate] {
                ovulationTypes.removeAll { $0 == .ovulation }
                predictedEventsByDay[ovulationDate] = ovulationTypes
            }

            if let fertileStart = ovulationDate
                .flatMap({ calendar.date(byAdding: .day, value: -5, to: $0) })
                .map({ calendar.startOfDay(for: $0) }),
               let fertileEnd = ovulationDate
                .flatMap({ calendar.date(byAdding: .day, value: 1, to: $0) })
                .map({ calendar.startOfDay(for: $0) }) {
                for day in Date.dates(
                    from: fertileStart,
                    to: fertileEnd,
                    calendar: calendar
                ) {
                    let normalizedDay = calendar.startOfDay(for: day)
                    guard var types = predictedEventsByDay[normalizedDay] else { continue }
                    types.removeAll { $0 == .fertile }
                    predictedEventsByDay[normalizedDay] = types
                }
            }

            guard cycleLength > 0,
                  let rawNextPeriodStart = calendar.date(
                    byAdding: .day,
                    value: cycleLength,
                    to: periodStart
                  ) else {
                continue
            }
            let nextPeriodStart = calendar.startOfDay(for: rawNextPeriodStart)
            for date in Array(predictedEventsByDay.keys) {
                let day = calendar.startOfDay(for: date)
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
