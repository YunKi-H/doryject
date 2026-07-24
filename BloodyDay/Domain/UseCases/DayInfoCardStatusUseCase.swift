//
//  DayInfoCardStatusUseCase.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

enum DayInfoCardStatusUseCase {
    static func primaryStatus(
        for date: Date,
        today: Date,
        periodDates: [Date],
        pillDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar
    ) -> DayInfoCardPrimarySnapshot {
        let summaries = PeriodSummaryBuilder.build(from: periodDates)
        let target = date.startOfDay
        let normalizedToday = today.startOfDay
        
        if let ongoing = summaries.first(where: { $0.start.startOfDay <= target && target <= $0.end.startOfDay }) {
            if target == ongoing.start.startOfDay {
                return .bDay
            }
            let dayIndex = (calendar.dateComponents([.day], from: ongoing.start.startOfDay, to: target).day ?? 0) + 1
            return .ongoing(day: max(dayIndex, 1))
        }
        
        if let latestStart = summaries.map({ $0.start.startOfDay }).max(), target < latestStart {
            return .unknown
        }
        
        guard let context = PeriodForecastCalculator.predictionContext(
            target: normalizedToday,
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            calendar: calendar
        ) else {
            return .unknown
        }
        
        let predictedStarts = predictedStartsForPrimaryStatus(
            target: target,
            today: normalizedToday,
            settings: settings,
            summaries: summaries,
            pillDates: pillDates,
            context: context,
            calendar: calendar
        )
        guard predictedStarts.isEmpty == false else {
            return .unknown
        }

        let predictedLength = max(context.predictedLength, 1)
        if let containingStart = predictedStarts.first(where: { start in
            guard let endExclusive = calendar.date(byAdding: .day, value: predictedLength, to: start.startOfDay) else {
                return false
            }
            return target >= start.startOfDay && target < endExclusive.startOfDay
        }) {
            if target == containingStart.startOfDay {
                return .bDay
            }
            let dayIndex = (calendar.dateComponents([.day], from: containingStart.startOfDay, to: target).day ?? 0) + 1
            return .ongoing(day: max(dayIndex, 1))
        }

        if target <= normalizedToday,
           let delayedStart = PeriodForecastCalculator.delayedPeriodStart(
            for: target,
            predictedStarts: predictedStarts,
            predictedLength: predictedLength,
            calendar: calendar
           ) {
            let delayedDays = calendar.dateComponents([.day], from: delayedStart.startOfDay, to: target).day ?? 0
            return .delayed(days: max(delayedDays, 0))
        }

        guard let nextStart = predictedStarts.first(where: { $0.startOfDay > target }) else {
            return .unknown
        }
        let daysUntil = calendar.dateComponents([.day], from: target, to: nextStart.startOfDay).day ?? 0
        return .countdown(days: max(daysUntil, 0))
    }
    
    static func secondaryStatus(
        for date: Date,
        allEventsEmpty: Bool,
        isPillEnabled: Bool,
        dayEvents: [DayEvent]?,
        pillDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar
    ) -> DayInfoCardSecondarySnapshot {
        if allEventsEmpty {
            return .unknown
        }
        
        if isPillEnabled, let pillInfo = pillInfo(for: date, pillDates: pillDates, settings: settings, calendar: calendar) {
            return .pill(day: pillInfo.day, total: pillInfo.total)
        }
        
        if isPillEnabled, let breakInfo = pillBreakInfo(for: date, pillDates: pillDates, settings: settings, calendar: calendar) {
            return .pillBreak(day: breakInfo.day, total: breakInfo.total)
        }
        
        if isPillEnabled, let scheduled = scheduledPillStatusForCurrentCycle(for: date, pillDates: pillDates, settings: settings, calendar: calendar) {
            return scheduled
        }
        
        guard let dayEvents else {
            return .notFertile
        }
        
        if dayEvents.contains(where: { $0.type == .ovulation }) {
            return .ovulation
        }
        
        if dayEvents.contains(where: { $0.type == .fertile }) {
            return .fertile
        }
        
        return .notFertile
    }
    
    private static func pillInfo(
        for date: Date,
        pillDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar
    ) -> (day: Int, total: Int?)? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let target = date.startOfDay
        guard pillDates.contains(target) else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let sequenceByDate = PeriodForecastCalculator.pillSequenceMap(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        guard let sequence = sequenceByDate[target] else { return nil }
        return (day: sequence, total: pillCount > 0 ? pillCount : nil)
    }

    private static func predictedStartsForPrimaryStatus(
        target: Date,
        today: Date,
        settings: UserSettings,
        summaries: [PeriodSummary],
        pillDates: Set<Date>,
        context: PeriodPredictionContext,
        calendar: Calendar
    ) -> [Date] {
        let cycleLength = max(context.cycleLength, 1)
        let searchBase = min(target.startOfDay, today.startOfDay)
        let searchEndBase = max(target.startOfDay, today.startOfDay)
        guard let rangeStart = calendar.date(
            byAdding: .day,
            value: -cycleLength,
            to: searchBase
        )?.startOfDay,
              let rangeEndExclusive = calendar.date(
                byAdding: .day,
                value: cycleLength * 2 + max(context.predictedLength, 1),
                to: searchEndBase
              )?.startOfDay else {
            return []
        }

        return PeriodForecastCalculator.predictedPeriodStarts(
            rangeStart: rangeStart,
            rangeEndExclusive: rangeEndExclusive,
            today: today,
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            calendar: calendar
        )
    }
    
    private static func pillBreakInfo(
        for date: Date,
        pillDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar
    ) -> (day: Int, total: Int)? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let autoRecordEnabled = pillSettings.pillAutoRecordEnabled
        guard pillCount > 0, breakDays > 0 else { return nil }
        
        let target = date.startOfDay
        
        if autoRecordEnabled == false {
            guard let projection = PeriodForecastCalculator.latestPillCycleProjection(
                settings: settings,
                pillDates: pillDates,
                calendar: calendar
            ),
                  let breakStart = calendar.date(byAdding: .day, value: 1, to: projection.projectedLastIntakeDate.startOfDay),
                  let breakEndExclusive = calendar.date(byAdding: .day, value: breakDays, to: breakStart.startOfDay) else {
                return nil
            }
            
            guard target >= breakStart.startOfDay && target < breakEndExclusive.startOfDay else { return nil }
            let breakDay = (calendar.dateComponents([.day], from: breakStart.startOfDay, to: target).day ?? 0) + 1
            return (day: breakDay, total: breakDays)
        }
        
        let cycles = PillCycleCalculator.groupedCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        
        for (index, cycle) in cycles.enumerated() {
            guard let lastIntake = cycle.last else { continue }
            guard let breakStart = calendar.date(byAdding: .day, value: 1, to: lastIntake.startOfDay),
                  let configuredBreakEndExclusive = calendar.date(byAdding: .day, value: breakDays, to: breakStart.startOfDay) else {
                continue
            }
            let nextCycleStart = cycles.indices.contains(index + 1) ? cycles[index + 1].first?.startOfDay : nil
            let breakEndExclusive = min(configuredBreakEndExclusive.startOfDay, nextCycleStart ?? configuredBreakEndExclusive.startOfDay)
            guard target >= breakStart.startOfDay && target < breakEndExclusive.startOfDay else { continue }
            let breakDay = (calendar.dateComponents([.day], from: breakStart.startOfDay, to: target).day ?? 0) + 1
            return (day: breakDay, total: breakDays)
        }
        
        return nil
    }
    
    private static func scheduledPillStatusForCurrentCycle(
        for date: Date,
        pillDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar
    ) -> DayInfoCardSecondarySnapshot? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        guard pillCount > 0 else { return nil }
        
        let target = date.startOfDay
        
        if pillSettings.pillAutoRecordEnabled {
            return nil
        }
        
        guard let currentCycle = PillCycleCalculator.latestCycle(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        ),
              let cycleStart = currentCycle.first,
              let cycleLastIntake = currentCycle.last,
              target >= cycleStart.startOfDay else {
            return nil
        }
        
        let sequenceByDate = PeriodForecastCalculator.pillSequenceMap(
            pillDates: Set(currentCycle),
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        
        var inferredCount: Int?
        if let exact = sequenceByDate[target] {
            inferredCount = exact
        } else if target > cycleLastIntake.startOfDay,
                  let lastKnownCount = sequenceByDate[cycleLastIntake.startOfDay] {
            let daysAfterLastIntake = calendar.dateComponents([.day], from: cycleLastIntake.startOfDay, to: target).day ?? -1
            if daysAfterLastIntake >= 1 {
                inferredCount = lastKnownCount + daysAfterLastIntake
            }
        } else {
            let offsetFromStart = calendar.dateComponents([.day], from: cycleStart.startOfDay, to: target).day ?? -1
            if offsetFromStart >= 0 {
                inferredCount = offsetFromStart + 1
            }
        }
        
        guard let count = inferredCount, count > 0 else { return nil }
        if count <= pillCount {
            return .pill(day: count, total: pillCount)
        }
        
        let breakDay = count - pillCount
        guard breakDays > 0, breakDay > 0, breakDay <= breakDays else { return nil }
        return .pillBreak(day: breakDay, total: breakDays)
    }
}
