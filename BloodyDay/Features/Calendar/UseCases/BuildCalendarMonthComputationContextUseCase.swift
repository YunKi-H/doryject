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
        let predictedLengthDays = PeriodForecastCalculator.predictedPeriodLengthDays(
            settings: settings,
            periodSummaries: periodSummaries
        )
        let predictedPeriodStarts = PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: bounds.start,
            rangeEndExclusive: bounds.endExclusive,
            today: normalizedToday,
            settings: settings,
            periodSummaries: periodSummaries,
            pillDates: allPillDates,
            calendar: calendar
        )
        var predictedEventsByDay = PredictedCycleEventBuilder.buildEvents(
            predictedPeriodStarts: predictedPeriodStarts,
            rangeStart: bounds.start,
            rangeEndExclusive: bounds.endExclusive,
            predictedLengthDays: predictedLengthDays,
            today: normalizedToday,
            calendar: calendar
        )
        
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
        manualCycleDays(for: settings) ??
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
    
    private static func manualCycleDays(for settings: UserSettings) -> Int? {
        let periodSettings = settings.period
        guard periodSettings.autoCyclePredictionEnabled == false else {
            return nil
        }
        return periodSettings.averageCycleDays
    }
    
    private static func averageCycleLengthDays(from summaries: [PeriodSummary]) -> Int? {
        let cycleDays = summaries.compactMap(\.cycleDays).filter { $0 > 0 }
        guard cycleDays.isEmpty == false else { return nil }
        let avg = Double(cycleDays.reduce(0, +)) / Double(cycleDays.count)
        let rounded = Int(round(avg))
        return rounded > 0 ? rounded : nil
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
