//
//  BuildCalendarMonthComputationContextUseCase.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

struct MonthComputationContext {
    let eventsByDay: [Date: [DayEvent]]
    let pillDates: Set<Date>
    let pillSequenceByDate: [Date: Int]
    let predictedEventsByDay: [Date: [EventType]]
    let predictedPeriodDates: Set<Date>
}

enum BuildCalendarMonthComputationContextUseCase {
    static func execute(
        bounds: (start: Date, endExclusive: Date),
        userEvents: [UserEvent],
        allPeriodEvents: [UserEvent],
        allPillDates: Set<Date>,
        settings: UserSettings,
        today: Date,
        calendar: Calendar = .current
    ) -> MonthComputationContext {
        let normalizedToday = today.startOfDay
        let groupedEvents = Dictionary(grouping: userEvents) { $0.date.startOfDay }
        let eventsByDay = groupedEvents.mapValues { dayEvents in
            dayEvents.map { DayEvent(type: $0.type) }
        }
        
        let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: allPillDates,
            calendar: calendar
        )
        let pillCycleRange = projectedPillCycleRangeForFertilitySuppression(
            settings: settings,
            projection: projection,
            calendar: calendar
        )
        let suppressFutureFertilityPrediction = shouldSuppressFutureFertilityPrediction(
            today: normalizedToday,
            pillCycleRange: pillCycleRange
        )
        
        let pillSettings = settings.pill
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let pillSequenceByDate = PeriodForecastCalculator.pillSequenceMap(
            pillDates: allPillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        
        let periodSummaries = PeriodSummaryBuilder.build(from: allPeriodEvents.map(\.date))
        let manualAverages = manualCycleAverages(for: settings)
        let prediction = CyclePrediction.predictEvents(
            periodEvents: allPeriodEvents,
            rangeStart: bounds.start,
            rangeEndExclusive: bounds.endExclusive,
            avgCycleDays: manualAverages.cycleDays,
            avgPeriodDays: manualAverages.periodDays
        )
        var predictedEventsByDay = prediction.predictedEventsByDay
        
        if projection != nil,
           let sharedPrediction = sharedPeriodPrediction(
            rangeStart: bounds.start,
            rangeEndExclusive: bounds.endExclusive,
            settings: settings,
            periodSummaries: periodSummaries,
            pillDates: allPillDates,
            today: normalizedToday,
            predictedLengthDays: PeriodForecastCalculator.predictedPeriodLengthDays(
                settings: settings,
                periodSummaries: periodSummaries
            ),
            calendar: calendar
        ) {
            for key in predictedEventsByDay.keys {
                predictedEventsByDay[key] = predictedEventsByDay[key]?.filter {
                    $0 != .period && $0 != .delayed && $0 != .ovulation && $0 != .fertile
                } ?? []
            }
            for (key, types) in sharedPrediction {
                var merged = predictedEventsByDay[key, default: []]
                for type in types where !merged.contains(type) {
                    merged.append(type)
                }
                predictedEventsByDay[key] = merged
            }
        }
        
        if let pillCycleRange {
            for key in predictedEventsByDay.keys {
                var events = predictedEventsByDay[key] ?? []
                events.removeAll { type in
                    guard type == .fertile || type == .ovulation else { return false }
                    return key >= pillCycleRange.start.startOfDay && key < pillCycleRange.end.startOfDay
                }
                predictedEventsByDay[key] = events
            }
        }
        
        if suppressFutureFertilityPrediction {
            for key in predictedEventsByDay.keys where key > normalizedToday {
                var events = predictedEventsByDay[key] ?? []
                events.removeAll { $0 == .fertile || $0 == .ovulation }
                predictedEventsByDay[key] = events
            }
        }
        
        let estimatedCycleLength =
        projection?.cycleLength ??
        manualAverages.cycleDays ??
        averageCycleLengthDays(from: periodSummaries)
        
        PeriodForecastCalculator.suppressPredictedCycleArtifactsOverlappingActualPeriods(
            predictedEventsByDay: &predictedEventsByDay,
            actualPeriodSummaries: periodSummaries,
            estimatedCycleLength: estimatedCycleLength,
            calendar: calendar
        )
        
        var predictedPeriodDates: Set<Date> = []
        for (date, types) in predictedEventsByDay where date >= bounds.start && date < bounds.endExclusive {
            if types.contains(.period) || types.contains(.delayed) {
                predictedPeriodDates.insert(date.startOfDay)
            }
        }
        
        return MonthComputationContext(
            eventsByDay: eventsByDay,
            pillDates: allPillDates,
            pillSequenceByDate: pillSequenceByDate,
            predictedEventsByDay: predictedEventsByDay,
            predictedPeriodDates: predictedPeriodDates
        )
    }
    
    private static func manualCycleAverages(for settings: UserSettings) -> (cycleDays: Int?, periodDays: Int?) {
        let periodSettings = settings.period
        guard periodSettings.autoCyclePredictionEnabled == false else {
            return (nil, nil)
        }
        return (periodSettings.averageCycleDays, periodSettings.averagePeriodDays)
    }
    
    private static func averageCycleLengthDays(from summaries: [PeriodSummary]) -> Int? {
        let cycleDays = summaries.compactMap(\.cycleDays).filter { $0 > 0 }
        guard cycleDays.isEmpty == false else { return nil }
        let avg = Double(cycleDays.reduce(0, +)) / Double(cycleDays.count)
        let rounded = Int(round(avg))
        return rounded > 0 ? rounded : nil
    }
    
    private static func sharedPeriodPrediction(
        rangeStart: Date,
        rangeEndExclusive: Date,
        settings: UserSettings,
        periodSummaries: [PeriodSummary],
        pillDates: Set<Date>,
        today: Date,
        predictedLengthDays: Int,
        calendar: Calendar
    ) -> [Date: [EventType]]? {
        let starts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: rangeStart,
            rangeEndExclusive: rangeEndExclusive,
            today: today,
            settings: settings,
            periodSummaries: periodSummaries,
            pillDates: pillDates,
            calendar: calendar
        )
        guard starts.isEmpty == false else {
            return nil
        }
        
        let normalizedStart = rangeStart.startOfDay
        let normalizedEnd = rangeEndExclusive.startOfDay
        let lengthDays = max(predictedLengthDays, 1)
        let lutealDays = 14
        var predicted: [Date: [EventType]] = [:]
        
        for cyclePredictedStart in starts.map(\.startOfDay) {
            guard let cycleEndExclusive = calendar.date(byAdding: .day, value: lengthDays, to: cyclePredictedStart) else {
                continue
            }
            let ovulation = calendar.date(byAdding: .day, value: -lutealDays, to: cyclePredictedStart)!.startOfDay
            let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation)!.startOfDay
            let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation)!.startOfDay
            
            if cycleEndExclusive <= normalizedStart {
                continue
            }
            if fertileStart >= normalizedEnd {
                continue
            }
            
            for day in Date.dates(from: cyclePredictedStart, toExclusive: cycleEndExclusive) {
                guard day >= normalizedStart && day < normalizedEnd else { continue }
                let type: EventType = day < today ? .delayed : .period
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
        
        return predicted.mapValues { types in
            var seen: Set<EventType> = []
            var unique: [EventType] = []
            for type in types where !seen.contains(type) {
                seen.insert(type)
                unique.append(type)
            }
            return unique
        }
    }
    
    private static func projectedPillCycleRangeForFertilitySuppression(
        settings: UserSettings,
        projection: PillCycleProjection?,
        calendar: Calendar
    ) -> DateInterval? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard cycleLength > 0 else { return nil }
        
        guard let projection,
              let cycleEndExclusive = calendar.date(byAdding: .day, value: cycleLength, to: projection.cycleStart.startOfDay) else {
            return nil
        }
        
        return DateInterval(start: projection.cycleStart.startOfDay, end: cycleEndExclusive.startOfDay)
    }
    
    private static func shouldSuppressFutureFertilityPrediction(
        today: Date,
        pillCycleRange: DateInterval?
    ) -> Bool {
        guard let pillCycleRange else { return false }
        return today >= pillCycleRange.start.startOfDay && today < pillCycleRange.end.startOfDay
    }
}
