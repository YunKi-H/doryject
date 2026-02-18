//
//  CalendarViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import Foundation
import Observation

@Observable
final class CalendarViewModel {
    var selectedDate: Date = .now
    
    var months: [MonthInfo] = []
    var currentIndex: Int = 0
    
    private let eventRepository: EventRepository
    private let settingsRepository: SettingsRepository?
    
    init(eventRepository: EventRepository, settingsRepository: SettingsRepository? = nil) {
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        
        bootstrapMonths(anchor: selectedDate)
    }
    
    func refresh() {
        if months.isEmpty {
            bootstrapMonths(anchor: selectedDate)
            return
        }
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    func moveSelectedDate(by days: Int) {
        let calendar = Calendar.current
        let next = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        selectDate(next)
    }
    
    func toggleStatesForSelectedDate() -> (period: Bool, pill: Bool, love: Bool) {
        (
            isEventOnSelectedDate(.period),
            isEventOnSelectedDate(.pill),
            isEventOnSelectedDate(.love)
        )
    }
}

// Repository
extension CalendarViewModel {
    func isEventOnSelectedDate(_ type: EventType) -> Bool {
        let target = selectedDate.startOfDay
        return eventRepository.events(of: type).contains { $0.date.startOfDay == target }
    }
    
    func setEvent(_ type: EventType, enabled: Bool) {
        let date = selectedDate.startOfDay
        let alreadySet = isEventOnSelectedDate(type)
        if enabled == alreadySet {
            return
        }
        if enabled {
            if type == .period {
                addPeriodEvents(startingAt: date)
            } else if type == .pill, shouldAutoRecordPill {
                addPillEvents(startingAt: date)
            } else {
                let new = UserEvent(id: .init(), date: date, type: type)
                eventRepository.save(new)
            }
        } else {
            if type == .period {
                deletePeriodEvents(startingAt: date)
            } else {
                eventRepository.delete(type: type, on: date)
            }
        }
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : date.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
}

// UI
extension CalendarViewModel {
    func selectDate(_ date: Date) {
        if !selectedDate.isInSameMonth(as: date) {
            setCurrentMonth(to: date)
        }
        selectedDate = date
    }
    
    func setCurrentMonth(to month: Date) {
        let start = month.startOfMonth
        
        if let idx = months.firstIndex(where: { $0.monthDate == start }) {
            currentIndex = idx
            loadPreviousIfNeeded(viewingIndex: currentIndex)
            loadNextIfNeeded(viewingIndex: currentIndex)
        } else {
            bootstrapMonths(anchor: start)
        }
    }
    
    private func loadPreviousIfNeeded(viewingIndex index: Int) {
        guard months.indices.contains(index), index <= 1, let first = months.first?.monthDate else { return }
        let prev = first.addingMonths(-1).startOfMonth
        let monthDates = [prev] + months.map(\.monthDate)
        let keepingMonth = months[index].monthDate
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard months.indices.contains(index), index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = last.addingMonths(+1).startOfMonth
        let monthDates = months.map(\.monthDate) + [next]
        let keepingMonth = months[index].monthDate
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func bootstrapMonths(anchor: Date) {
        let anchorMonth = anchor.startOfMonth
        let monthDates = [
            anchorMonth.addingMonths(-1),
            anchorMonth,
            anchorMonth.addingMonths(1)
        ]
        rebuildMonths(monthDates: monthDates, keepingMonth: anchorMonth)
    }
    
    private func recomputeLoadedMonths(keepingMonth: Date) {
        if months.isEmpty {
            bootstrapMonths(anchor: keepingMonth)
            return
        }
        
        let monthDates = months.map(\.monthDate)
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func rebuildMonths(monthDates: [Date], keepingMonth: Date) {
        let normalizedMonthDates = monthDates.map(\.startOfMonth)
        let calculationEvents = calculationEvents(for: normalizedMonthDates)
        months = normalizedMonthDates.map { makeMonthInfo(for: $0, userEvents: calculationEvents) }
        
        if let idx = months.firstIndex(where: { $0.monthDate == keepingMonth.startOfMonth }) {
            currentIndex = idx
        } else {
            currentIndex = min(currentIndex, max(months.count - 1, 0))
        }
    }
    
    private func calculationEvents(for monthDates: [Date]) -> [UserEvent] {
        guard let firstMonth = monthDates.min(),
              let lastMonth = monthDates.max() else {
            return []
        }
        let calculationRangeStart = firstMonth.startOfMonth.addingMonths(-1)
        let calculationRangeEndExclusive = lastMonth.startOfMonth.addingMonths(2)
        return eventRepository.allEvents().filter {
            let day = $0.date.startOfDay
            return day >= calculationRangeStart && day < calculationRangeEndExclusive
        }
    }
    
    private func makeMonthInfo(for month: Date, userEvents: [UserEvent]) -> MonthInfo {
        let monthStart = month.startOfMonth
        let actualPeriodDates = Set(userEvents.filter { $0.type == .period }.map { $0.date.startOfDay })
        let result = buildDayInfos(for: monthStart, userEvents: userEvents)
        let days: [DayInfo] = result.days
        let predictedPeriodDates: Set<Date> = result.predictedPeriodDates
        
        let periodRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            actualPeriodDates.contains(day.date.startOfDay)
        }
        let predictedPeriodRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            predictedPeriodDates.contains(day.date.startOfDay)
        }
        let delayedRanges: [DateInterval] = []
        let fertileRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            day.events.contains { $0.type == .fertile }
        }
        let ovulationRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            day.events.contains { $0.type == .ovulation }
        }
        
        return MonthInfo(
            monthDate: monthStart,
            days: days,
            periodRanges: periodRanges,
            predictedPeriodRanges: predictedPeriodRanges,
            predictedPeriodDates: predictedPeriodDates,
            delayedRanges: delayedRanges,
            fertileRanges: fertileRanges,
            ovulationRanges: ovulationRanges
        )
    }
    
    private func buildDayInfos(
        for month: Date,
        userEvents: [UserEvent]
    ) -> (days: [DayInfo], predictedPeriodDates: Set<Date>) {
        let gridStart = month.startOfCalendarGrid()
        let gridEndExclusive = month.endOfCalendarGridExclusiveStart()
        
        var days: [DayInfo] = Date.dates(from: gridStart, to: gridEndExclusive).map { DayInfo(date: $0) }
        
        let eventsByDay = Dictionary(grouping: userEvents) { $0.date.startOfDay }
        for i in days.indices {
            let key = days[i].date.startOfDay
            let dayEvents: [DayEvent] = eventsByDay[key]?.map { DayEvent(type: $0.type) } ?? []
            days[i].events = dayEvents
        }
        
        let periodEvents = userEvents.filter { $0.type == .period }
        let manualAverages = manualCycleAverages()
        let prediction = CyclePrediction.predictEvents(
            periodEvents: periodEvents,
            rangeStart: gridStart,
            rangeEndExclusive: gridEndExclusive,
            avgCycleDays: manualAverages.cycleDays,
            avgPeriodDays: manualAverages.periodDays
        )
        var predictedEventsByDay = prediction.predictedEventsByDay
        if let pillPrediction = pillBasedPeriodPrediction(
            rangeStart: gridStart,
            rangeEndExclusive: gridEndExclusive
        ) {
            for key in predictedEventsByDay.keys {
                predictedEventsByDay[key] = predictedEventsByDay[key]?.filter {
                    $0 != .period && $0 != .delayed && $0 != .ovulation && $0 != .fertile
                } ?? []
            }
            for (key, types) in pillPrediction {
                var merged = predictedEventsByDay[key, default: []]
                for type in types where !merged.contains(type) {
                    merged.append(type)
                }
                predictedEventsByDay[key] = merged
            }
        }
        
        var predictedPeriodDates: Set<Date> = []
        if !predictedEventsByDay.isEmpty {
            for i in days.indices {
                let key = days[i].date.startOfDay
                guard let predicted = predictedEventsByDay[key] else { continue }
                for type in predicted where !days[i].events.contains(where: { $0.type == type }) {
                    days[i].events.append(DayEvent(type: type))
                    if type == .period || type == .delayed {
                        predictedPeriodDates.insert(key)
                    }
                }
            }
        }
        
        let calendar = Calendar.current
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let predictedPillDates = predictedPillDates(
            rangeStart: gridStart,
            rangeEndExclusive: gridEndExclusive,
            pillDates: pillDates
        )
        if !predictedPillDates.isEmpty {
            for i in days.indices {
                let key = days[i].date.startOfDay
                if predictedPillDates.contains(key),
                   !days[i].events.contains(where: { $0.type == .pill }) {
                    days[i].events.append(DayEvent(type: .pill))
                }
            }
        }
        let allPillDates = pillDates.union(predictedPillDates)
        let pillSettings = settingsRepository?.load().pill
        let pillCount = max(pillSettings?.pillCount ?? 0, 0)
        let breakDays = max(pillSettings?.pillBreakDuration ?? 0, 0)
        let cycleLength = pillCount + breakDays
        let pillAnchor = mostRecentPillStart(from: pillDates, calendar: .current)

        for i in days.indices {
            let dayDate = days[i].date.startOfDay
            guard allPillDates.contains(dayDate),
                  let pillAnchor,
                  cycleLength > 0,
                  pillCount > 0 else {
                days[i].pillSequence = nil
                continue
            }

            let daysFromAnchor = calendar.dateComponents([.day], from: pillAnchor.startOfDay, to: dayDate).day ?? -1
            guard daysFromAnchor >= 0 else {
                days[i].pillSequence = nil
                continue
            }
            let indexInCycle = daysFromAnchor % cycleLength
            days[i].pillSequence = indexInCycle < pillCount ? indexInCycle + 1 : nil
        }
        
        return (days, predictedPeriodDates)
    }
    
    private func pillBasedPeriodPrediction(
        rangeStart: Date,
        rangeEndExclusive: Date
    ) -> [Date: [EventType]]? {
        guard isPillEnabled else { return nil }
        let pillDates = eventRepository.events(of: .pill).map { $0.date.startOfDay }
        guard let anchor = mostRecentPillStart(from: Set(pillDates), calendar: .current) else { return nil }
        let pillSettings = settingsRepository?.load().pill
        let pillCount = max(pillSettings?.pillCount ?? 0, 0)
        let breakDays = max(pillSettings?.pillBreakDuration ?? 0, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        let calendar = Calendar.current
        guard let lastPillInFirstCycle = calendar.date(byAdding: .day, value: pillCount - 1, to: anchor.startOfDay),
              let firstPredictedStart = calendar.date(byAdding: .day, value: 3, to: lastPillInFirstCycle) else {
            return nil
        }
        
        let normalizedStart = rangeStart.startOfDay
        let normalizedEnd = rangeEndExclusive.startOfDay
        let today = Date().startOfDay
        let lengthDays = max(periodAutoLengthDays(), 1)
        let lutealDays = 14
        var predicted: [Date: [EventType]] = [:]
        var cyclePredictedStart = firstPredictedStart.startOfDay
        
        while true {
            guard let cycleEndExclusive = calendar.date(byAdding: .day, value: lengthDays, to: cyclePredictedStart) else {
                break
            }
            let ovulation = calendar.date(byAdding: .day, value: -lutealDays, to: cyclePredictedStart)!.startOfDay
            let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation)!.startOfDay
            let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation)!.startOfDay
            
            if cycleEndExclusive <= normalizedStart {
                guard let nextCycleStart = calendar.date(byAdding: .day, value: cycleLength, to: cyclePredictedStart) else {
                    break
                }
                cyclePredictedStart = nextCycleStart.startOfDay
                continue
            }
            if fertileStart >= normalizedEnd {
                break
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
            
            guard let nextCycleStart = calendar.date(byAdding: .day, value: cycleLength, to: cyclePredictedStart) else {
                break
            }
            cyclePredictedStart = nextCycleStart.startOfDay
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
    
    private func buildRangesSplittingByWeeks(
        days: [DayInfo],
        hasEvent: (DayInfo) -> Bool,
        columns: Int = 7
    ) -> [DateInterval] {
        var ranges: [DateInterval] = []
        var currentStart: Date? = nil
        var lastIndex: Int? = nil
        
        for idx in days.indices {
            let day = days[idx]
            let isOn = hasEvent(day)
            
            if isOn {
                if currentStart == nil {
                    currentStart = day.date
                    lastIndex = idx
                } else {
                    if let li = lastIndex, li % columns == columns - 1 {
                        // 주 경계에서 끊기
                        let endDate = days[li].date
                        ranges.append(DateInterval(start: currentStart!, end: endDate))
                        currentStart = day.date
                    }
                    lastIndex = idx
                }
            } else if let li = lastIndex, let start = currentStart {
                // 연속 구간 종료
                let endDate = days[li].date
                ranges.append(DateInterval(start: start, end: endDate))
                currentStart = nil
                lastIndex = nil
            }
        }
        
        if let li = lastIndex, let start = currentStart {
            let endDate = days[li].date
            ranges.append(DateInterval(start: start, end: endDate))
        }
        
        return ranges
    }
    
    private func addPeriodEvents(startingAt date: Date) {
        let normalizedDate = date.startOfDay
        let periodEvents = eventRepository.events(of: .period).map { $0.date.startOfDay }
        let calendar = Calendar.current
        let previousDay = calendar.date(byAdding: .day, value: -1, to: normalizedDate)!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: normalizedDate)!
        let isAdjacent = periodEvents.contains(where: { $0.isSameDay(as: previousDay) }) ||
        periodEvents.contains(where: { $0.isSameDay(as: nextDay) })
        
        let datesToAdd: [Date]
        if isAdjacent {
            datesToAdd = [normalizedDate]
        } else {
            let lengthDays = max(periodAutoLengthDays(), 1)
            let endExclusive = calendar.date(byAdding: .day, value: lengthDays, to: normalizedDate)!
            datesToAdd = Date.dates(from: normalizedDate, toExclusive: endExclusive)
        }
        
        for day in datesToAdd {
            let new = UserEvent(id: .init(), date: day, type: .period)
            eventRepository.save(new)
        }
    }
    
    private func deletePeriodEvents(startingAt date: Date) {
        let calendar = Calendar.current
        let periodDates = Set(eventRepository.events(of: .period).map { $0.date.startOfDay })
        var cursor = date.startOfDay
        guard periodDates.contains(cursor) else { return }
        
        while periodDates.contains(cursor) {
            eventRepository.delete(type: .period, on: cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
    }
    
    private var shouldAutoRecordPill: Bool {
        guard let pillSettings = settingsRepository?.load().pill else { return false }
        return pillSettings.pillEnabled && pillSettings.pillAutoRecordEnabled
    }
    
    private var isPillEnabled: Bool {
        settingsRepository?.load().pill.pillEnabled == true
    }
    
    private func addPillEvents(startingAt date: Date) {
        guard let pillSettings = settingsRepository?.load().pill,
              pillSettings.pillAutoRecordEnabled else { return }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return }
        
        let calendar = Calendar.current
        let start = date.startOfDay
        let today = Date().startOfDay
        guard start <= today else { return }
        
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: today)!
        for day in Date.dates(from: start, toExclusive: endExclusive) {
            if isPillDay(
                day,
                anchor: start,
                pillCount: pillCount,
                breakDays: breakDays,
                calendar: calendar
            ) {
                let new = UserEvent(id: .init(), date: day, type: .pill)
                eventRepository.save(new)
            }
        }
    }
    
    private func predictedPillDates(
        rangeStart: Date,
        rangeEndExclusive: Date,
        pillDates: Set<Date>
    ) -> Set<Date> {
        guard let pillSettings = settingsRepository?.load().pill,
              pillSettings.pillEnabled,
              pillSettings.pillAutoRecordEnabled else { return [] }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return [] }
        guard let anchor = mostRecentPillStart(from: pillDates, calendar: .current) else { return [] }
        
        let start = max(rangeStart.startOfDay, anchor.startOfDay)
        var predicted: Set<Date> = []
        for day in Date.dates(from: start, to: rangeEndExclusive.startOfDay) {
            if pillDates.contains(day) { continue }
            if isPillDay(
                day,
                anchor: anchor.startOfDay,
                pillCount: pillCount,
                breakDays: breakDays,
                calendar: .current
            ) {
                predicted.insert(day)
            }
        }
        return predicted
    }
    
    private func mostRecentPillStart(
        from pillDates: Set<Date>,
        calendar: Calendar
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
    
    private func isPillDay(
        _ day: Date,
        anchor: Date,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar
    ) -> Bool {
        let cycleLength = pillCount + breakDays
        guard cycleLength > 0, pillCount > 0 else { return false }
        let daysFromAnchor = calendar.dateComponents([.day], from: anchor.startOfDay, to: day.startOfDay).day ?? 0
        guard daysFromAnchor >= 0 else { return false }
        let indexInCycle = daysFromAnchor % cycleLength
        return indexInCycle < pillCount
    }
}

// DayInfoCard
extension CalendarViewModel {
    func primaryStatus(for date: Date) -> CalendarPrimaryStatus {
        periodStatus(for: date)
    }
    
    func secondaryStatus(for date: Date) -> CalendarSecondaryStatus {
        calculateSecondaryStatus(for: date)
    }
    
    private func periodStatus(for date: Date) -> CalendarPrimaryStatus {
        let summaries = actualPeriodSummaries()
        let calendar = Calendar.current
        let target = date.startOfDay
        
        if let ongoing = summaries.first(where: { $0.start.startOfDay <= target && target <= $0.end.startOfDay }) {
            let dayIndex = (calendar.dateComponents([.day], from: ongoing.start.startOfDay, to: target).day ?? 0) + 1
            return .ongoing(day: max(dayIndex, 1))
        }
        
        guard let avgCycle = effectiveAverageCycleDays(from: summaries),
              let lastStart = summaries.last?.start.startOfDay else {
            return .unknown
        }
        
        let predictedStart = calendar.date(byAdding: .day, value: avgCycle, to: lastStart)!
        if target == predictedStart.startOfDay {
            return .bDay
        }
        if target >= predictedStart {
            return .delayed(days: max(calendar.dateComponents([.day], from: predictedStart.startOfDay, to: target).day ?? 0, 0))
        }
        
        let daysUntil = calendar.dateComponents([.day], from: target, to: predictedStart).day ?? 0
        return .countdown(days: max(daysUntil, 0))
    }
    
    private func calculateSecondaryStatus(for date: Date) -> CalendarSecondaryStatus {
        if eventRepository.allEvents().isEmpty {
            return .unknown
        }
        let shouldShowPillStatus = isPillEnabled
        if shouldShowPillStatus, let pillInfo = pillInfo(for: date) {
            return .pill(day: pillInfo.day, total: pillInfo.total)
        }
        
        if shouldShowPillStatus, let breakInfo = pillBreakInfo(for: date) {
            return .pillBreak(day: breakInfo.day, total: breakInfo.total)
        }
        
        guard let dayInfo = months
            .flatMap(\.days)
            .first(where: { $0.date.isSameDay(as: date) }) else {
            return .notFertile
        }
        
        if dayInfo.events.contains(where: { $0.type == .ovulation }) {
            return .ovulation
        }
        
        if dayInfo.events.contains(where: { $0.type == .fertile }) {
            return .fertile
        }
        
        return .notFertile
    }
    
    private func actualPeriodSummaries() -> [PeriodSummary] {
        let events = eventRepository.events(of: .period)
        return PeriodSummaryBuilder.build(from: events.map { $0.date })
    }
    
    private func averageCycleDays(from summaries: [PeriodSummary]) -> Int? {
        let cycles = summaries.compactMap(\.cycleDays)
        guard !cycles.isEmpty else { return nil }
        let avg = Double(cycles.reduce(0, +)) / Double(cycles.count)
        return Int(round(avg))
    }
    
    private func periodAutoLengthDays() -> Int {
        let settings = settingsRepository?.load().period
        if settings?.autoCyclePredictionEnabled == false, let manual = settings?.averagePeriodDays {
            return manual
        }
        let summaries = actualPeriodSummaries()
        let lengths = summaries.map(\.lengthDays).filter { $0 > 0 }
        if !lengths.isEmpty {
            let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
            return Int(round(avg))
        }
        return 5
    }
    
    private func effectiveAverageCycleDays(from summaries: [PeriodSummary]) -> Int? {
        let settings = settingsRepository?.load().period
        if settings?.autoCyclePredictionEnabled == false, let manual = settings?.averageCycleDays {
            return manual
        }
        return averageCycleDays(from: summaries)
    }
    
    private func manualCycleAverages() -> (cycleDays: Int?, periodDays: Int?) {
        guard let settings = settingsRepository?.load().period,
              settings.autoCyclePredictionEnabled == false else {
            return (nil, nil)
        }
        return (settings.averageCycleDays, settings.averagePeriodDays)
    }
    
    private func pillInfo(for date: Date) -> (day: Int, total: Int?)? {
        guard let pillSettings = settingsRepository?.load().pill else { return nil }
        guard pillSettings.pillEnabled else { return nil }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let anchor = mostRecentPillStart(from: pillDates, calendar: .current) else { return nil }
        
        let target = date.startOfDay
        guard target >= anchor.startOfDay else { return nil }
        let daysFromAnchor = Calendar.current.dateComponents([.day], from: anchor.startOfDay, to: target).day ?? 0
        let indexInCycle = daysFromAnchor % cycleLength
        guard indexInCycle < pillCount else { return nil }
        return (day: indexInCycle + 1, total: pillCount)
    }
    
    private func pillBreakInfo(for date: Date) -> (day: Int, total: Int)? {
        guard let pillSettings = settingsRepository?.load().pill else { return nil }
        guard pillSettings.pillEnabled else { return nil }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, breakDays > 0, cycleLength > 0 else { return nil }
        
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let anchor = mostRecentPillStart(from: pillDates, calendar: .current) else { return nil }
        
        let target = date.startOfDay
        guard target >= anchor.startOfDay else { return nil }
        let daysFromAnchor = Calendar.current.dateComponents([.day], from: anchor.startOfDay, to: target).day ?? 0
        let indexInCycle = daysFromAnchor % cycleLength
        guard indexInCycle >= pillCount else { return nil }
        let breakDay = indexInCycle - pillCount + 1
        return (day: breakDay, total: breakDays)
    }
}

enum CalendarPrimaryStatus: Equatable {
    case countdown(days: Int)
    case ongoing(day: Int)
    case bDay
    case delayed(days: Int)
    case unknown
    
    var displayText: String {
        switch self {
        case .countdown(let days):
            return "B-\(days)"
        case .ongoing(let day):
            return "B+\(day)"
        case .bDay:
            return "B-Day"
        case .delayed:
            return "생리 지연"
        case .unknown:
            return "-"
        }
    }
    
    var subText: String? {
        switch self {
        case .delayed(let days):
            return "(\(days)일 지연됨)"
        default:
            return nil
        }
    }
}

enum CalendarSecondaryStatus: Equatable {
    case pill(day: Int, total: Int?)
    case pillBreak(day: Int, total: Int)
    case ovulation
    case fertile
    case notFertile
    case unknown
    
    var displayText: String {
        switch self {
            
        case .pill(let day, let total):
            if let total, total > 0 {
                return "\(day)정 복용/\(total)정"
            }
            return "피임약 \(day)일째"
        case .pillBreak:
            return "휴약기"
        case .ovulation:
            return "임신 확률 높음"
        case .fertile:
            return "임신 확률 보통"
        case .notFertile:
            return "임신 확률 낮음"
        case .unknown:
            return "-"
        }
    }
    
    var subText: String? {
        switch self {
        case .pillBreak(let day, let total):
            return "(\(day)일째/\(total)일)"
        case .ovulation:
            return "(배란일)"
        case .fertile:
            return "(가임기)"
        default:
            return nil
        }
    }
}
