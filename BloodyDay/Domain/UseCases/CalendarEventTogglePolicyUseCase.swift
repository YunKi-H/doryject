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
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> CalendarEventMutationPlan {
        let target = calendar.startOfDay(for: selectedDate)
        let existingForType = Set(
            (existingDatesByType[type] ?? []).map { calendar.startOfDay(for: $0) }
        )
        let alreadySet = existingForType.contains(target)
        guard enabled != alreadySet else { return .init() }
        
        if enabled {
            return additionPlan(
                type: type,
                target: target,
                existingDatesByType: existingDatesByType,
                settings: settings,
                pillCycles: pillCycles,
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
        pillCycles: [PillCycleInfo] = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> PillDisableConfirmationPlan? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else {
            return nil
        }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        guard pillCount > 0 else { return nil }
        
        let selected = calendar.startOfDay(for: selectedDate)
        let normalizedPillDates = Set(pillDates.map { calendar.startOfDay(for: $0) })
        guard normalizedPillDates.contains(selected) else { return nil }

        if pillCycles.isEmpty == false {
            guard let cycle = PillCycleCalculator.cycleInfo(
                containing: selected,
                pillCycles: pillCycles,
                calendar: calendar
            ),
                  cycle.status == .active,
                  cycle.autoRecordEnabled == true else {
                return nil
            }
            let sortedDates = cycle.intakeDates
                .map { calendar.startOfDay(for: $0) }
                .sorted()
            let futureDates = sortedDates.filter { $0 > selected }
            guard futureDates.isEmpty == false else { return nil }
            return PillDisableConfirmationPlan(
                remainingCount: futureDates.count,
                todayOnlyDeleteDates: [selected],
                stopCycleDeleteDates: sortedDates.filter { $0 >= selected }
            )
        }

        guard pillSettings.pillAutoRecordEnabled else { return nil }
        
        guard let currentCycle = PillCycleCalculator.latestCycle(
            pillDates: normalizedPillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        ),
              currentCycle.contains(selected) else { return nil }
        
        let sortedCurrentCycle = currentCycle
            .map { calendar.startOfDay(for: $0) }
            .sorted()
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
        pillCycles: [PillCycleInfo],
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
            let pillDates = existingDatesByType[.pill] ?? []
            let storedCycle = matchingActiveCycle(
                for: target,
                pillCycles: pillCycles,
                calendar: calendar
            )
            let autoRecordEnabled = storedCycle?.autoRecordEnabled
                ?? pillSettings.pillAutoRecordEnabled
            if pillSettings.pillEnabled && autoRecordEnabled {
                let datesToAdd = autoRecordPillAddDates(
                    startingAt: target,
                    pillDates: pillDates,
                    pillCount: max(
                        storedCycle?.plannedPillCount ?? pillSettings.pillCount,
                        0
                    ),
                    breakDays: max(
                        storedCycle?.breakDays ?? pillSettings.pillBreakDuration,
                        0
                    ),
                    pillCycles: pillCycles,
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
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedPeriodDates = Set(periodDates.map { calendar.startOfDay(for: $0) })
        guard let rawPreviousDay = calendar.date(byAdding: .day, value: -1, to: normalizedDate),
              let rawNextDay = calendar.date(byAdding: .day, value: 1, to: normalizedDate) else {
            return [normalizedDate]
        }
        let previousDay = calendar.startOfDay(for: rawPreviousDay)
        let nextDay = calendar.startOfDay(for: rawNextDay)
        
        let isAdjacent = normalizedPeriodDates.contains(previousDay)
            || normalizedPeriodDates.contains(nextDay)
        if isAdjacent {
            return [normalizedDate]
        }
        
        let summaries = PeriodSummaryBuilder.build(
            from: Array(normalizedPeriodDates),
            calendar: calendar
        )
        let lengthDays = PeriodForecastCalculator.predictedPeriodLengthDays(
            settings: settings,
            periodSummaries: summaries
        )
        guard let rawEndExclusive = calendar.date(
            byAdding: .day,
            value: lengthDays,
            to: normalizedDate
        ) else {
            return [normalizedDate]
        }
        let endExclusive = calendar.startOfDay(for: rawEndExclusive)
        return Date.dates(
            from: normalizedDate,
            toExclusive: endExclusive,
            calendar: calendar
        )
    }
    
    private static func periodDeleteDates(
        startingAt date: Date,
        periodDates: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: date)
        let normalizedPeriodDates = Set(periodDates.map { calendar.startOfDay(for: $0) })
        guard normalizedPeriodDates.contains(start) else { return [] }
        
        var result: [Date] = []
        var cursor = start
        while normalizedPeriodDates.contains(cursor) {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        return result
    }
    
    private static func autoRecordPillAddDates(
        startingAt date: Date,
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        pillCycles: [PillCycleInfo],
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: date)

        if pillCycles.isEmpty == false {
            let matchingCycle = matchingActiveCycle(
                for: start,
                pillCycles: pillCycles,
                calendar: calendar
            )
            if let matchingCycle,
               let storedPillCount = matchingCycle.plannedPillCount {
                var cycleDates = Set(
                    matchingCycle.intakeDates.map { calendar.startOfDay(for: $0) }
                )
                var additions: [Date] = []
                var cursor = start
                while cycleDates.count < storedPillCount {
                    if cycleDates.contains(cursor) == false {
                        cycleDates.insert(cursor)
                        additions.append(cursor)
                    }
                    guard let next = calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: cursor
                    ) else {
                        break
                    }
                    cursor = calendar.startOfDay(for: next)
                }
                return additions
            }
        }

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
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: next)
        }
        return additions
    }

    private static func matchingActiveCycle(
        for date: Date,
        pillCycles: [PillCycleInfo],
        calendar: Calendar
    ) -> PillCycleInfo? {
        let target = calendar.startOfDay(for: date)
        return pillCycles
            .filter { cycle in
                guard cycle.status == .active,
                      let plannedCount = cycle.plannedPillCount,
                      cycle.intakeDates.count < plannedCount else {
                    return false
                }
                return cycle.intakeDates.contains {
                    abs(calendar.dateComponents(
                        [.day],
                        from: calendar.startOfDay(for: $0),
                        to: target
                    ).day ?? .max) <= 4
                }
            }
            .max(by: {
                ($0.startDate(calendar: calendar) ?? .distantPast)
                    < ($1.startDate(calendar: calendar) ?? .distantPast)
            })
    }
}
