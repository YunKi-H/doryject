//
//  CalendarEventTogglePolicyUseCase.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

enum CalendarEventTogglePolicyUseCase {
    static func mutationPlan(
        type: EventType,
        enabled: Bool,
        selectedDate: Date,
        existingDatesByType: [EventType: Set<Date>],
        settings: UserSettings,
        calendar: Calendar = .current
    ) -> CalendarEventMutationPlan {
        let target = selectedDate.startOfDay
        let existingForType = existingDatesByType[type] ?? []
        let alreadySet = existingForType.contains(target)
        guard enabled != alreadySet else { return .init() }
        
        if enabled {
            return additionPlan(
                type: type,
                target: target,
                existingDatesByType: existingDatesByType,
                settings: settings,
                calendar: calendar
            )
        }
        
        return deletionPlan(
            type: type,
            target: target,
            existingDatesByType: existingDatesByType,
            settings: settings,
            calendar: calendar
        )
    }
    
    static func pillDisableConfirmationPlan(
        selectedDate: Date,
        pillDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar = .current
    ) -> PillDisableConfirmationPlan? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled,
              pillSettings.pillAutoRecordEnabled else {
            return nil
        }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        guard pillCount > 0 else { return nil }
        
        let selected = selectedDate.startOfDay
        guard pillDates.contains(selected) else { return nil }
        
        guard let currentCycle = PillCycleCalculator.latestCycle(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        ),
              currentCycle.contains(selected) else { return nil }
        
        let sortedCurrentCycle = currentCycle.map(\.startOfDay).sorted()
        let futureDates = sortedCurrentCycle.filter { $0 > selected }
        guard futureDates.isEmpty == false else { return nil }
        
        let stopCycleDeleteDates = sortedCurrentCycle.filter { $0 >= selected }
        return PillDisableConfirmationPlan(
            remainingCount: futureDates.count,
            todayOnlyDeleteDates: [selected],
            stopCycleDeleteDates: stopCycleDeleteDates
        )
    }
    
    private static func additionPlan(
        type: EventType,
        target: Date,
        existingDatesByType: [EventType: Set<Date>],
        settings: UserSettings,
        calendar: Calendar
    ) -> CalendarEventMutationPlan {
        switch type {
        case .period:
            let periodDates = existingDatesByType[.period] ?? []
            let datesToAdd = periodAddDates(
                startingAt: target,
                periodDates: periodDates,
                settings: settings,
                calendar: calendar
            )
            return .init(additions: [CalendarEventMutation(type: .period, dates: datesToAdd)])
        case .pill:
            let pillSettings = settings.pill
            if pillSettings.pillEnabled && pillSettings.pillAutoRecordEnabled {
                let pillDates = existingDatesByType[.pill] ?? []
                let datesToAdd = autoRecordPillAddDates(
                    startingAt: target,
                    pillDates: pillDates,
                    pillCount: max(pillSettings.pillCount, 0),
                    breakDays: max(pillSettings.pillBreakDuration, 0),
                    calendar: calendar
                )
                return .init(additions: [CalendarEventMutation(type: .pill, dates: datesToAdd)])
            }
            return .init(additions: [CalendarEventMutation(type: .pill, dates: [target])])
        case .love:
            return .init(additions: [CalendarEventMutation(type: .love, dates: [target])])
        default:
            return .init(additions: [CalendarEventMutation(type: type, dates: [target])])
        }
    }
    
    private static func deletionPlan(
        type: EventType,
        target: Date,
        existingDatesByType: [EventType: Set<Date>],
        settings: UserSettings,
        calendar: Calendar
    ) -> CalendarEventMutationPlan {
        switch type {
        case .period:
            let periodDates = existingDatesByType[.period] ?? []
            let datesToDelete = periodDeleteDates(startingAt: target, periodDates: periodDates, calendar: calendar)
            return .init(deletions: [CalendarEventMutation(type: .period, dates: datesToDelete)])
        case .pill:
            return .init(deletions: [CalendarEventMutation(type: .pill, dates: [target])])
        case .love:
            return .init(deletions: [CalendarEventMutation(type: .love, dates: [target])])
        default:
            _ = settings
            return .init(deletions: [CalendarEventMutation(type: type, dates: [target])])
        }
    }
    
    private static func periodAddDates(
        startingAt date: Date,
        periodDates: Set<Date>,
        settings: UserSettings,
        calendar: Calendar
    ) -> [Date] {
        let normalizedDate = date.startOfDay
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: normalizedDate)?.startOfDay,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: normalizedDate)?.startOfDay else {
            return [normalizedDate]
        }
        
        let isAdjacent = periodDates.contains(previousDay) || periodDates.contains(nextDay)
        if isAdjacent {
            return [normalizedDate]
        }
        
        let summaries = PeriodSummaryBuilder.build(from: periodDates.map(\.startOfDay))
        let lengthDays = PeriodForecastCalculator.predictedPeriodLengthDays(
            settings: settings,
            periodSummaries: summaries
        )
        guard let endExclusive = calendar.date(byAdding: .day, value: lengthDays, to: normalizedDate)?.startOfDay else {
            return [normalizedDate]
        }
        return Date.dates(from: normalizedDate, toExclusive: endExclusive).map(\.startOfDay)
    }
    
    private static func periodDeleteDates(
        startingAt date: Date,
        periodDates: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        let start = date.startOfDay
        guard periodDates.contains(start) else { return [] }
        
        var result: [Date] = []
        var cursor = start
        while periodDates.contains(cursor) {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor)?.startOfDay else { break }
            cursor = next
        }
        return result
    }
    
    private static func autoRecordPillAddDates(
        startingAt date: Date,
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar
    ) -> [Date] {
        let start = date.startOfDay
        guard pillCount > 0 else { return [start] }
        
        var simulatedPillDates = pillDates
        var cycleDates = Set(
            PillCycleCalculator.cycle(
                containing: start,
                pillDates: simulatedPillDates,
                pillCount: pillCount,
                breakDays: breakDays,
                calendar: calendar
            ) ?? [start]
        )
        
        if cycleDates.count >= pillCount {
            return simulatedPillDates.contains(start) ? [] : [start]
        }
        
        var additions: [Date] = []
        var cursor = start
        while cycleDates.count < pillCount {
            if simulatedPillDates.contains(cursor) == false {
                additions.append(cursor)
                simulatedPillDates.insert(cursor)
                cycleDates = Set(
                    PillCycleCalculator.cycle(
                        containing: start,
                        pillDates: simulatedPillDates,
                        pillCount: pillCount,
                        breakDays: breakDays,
                        calendar: calendar
                    ) ?? [start]
                )
            }
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor)?.startOfDay else { break }
            cursor = next
        }
        return additions
    }
}
