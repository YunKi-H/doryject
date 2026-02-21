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

struct PillDisableConfirmationContext {
    let remainingCount: Int
    let datesToDeleteFromSelected: [Date]
}

private struct MonthComputationContext {
    let eventsByDay: [Date: [DayEvent]]
    let pillDates: Set<Date>
    let pillSequenceByDate: [Date: Int]
    let predictedEventsByDay: [Date: [EventType]]
    let predictedPeriodDates: Set<Date>
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
    
    func pillDisableConfirmationContextForSelectedDate() -> PillDisableConfirmationContext? {
        guard isEventOnSelectedDate(.pill),
              let settings = settingsRepository?.load() else {
            return nil
        }
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled,
              pillSettings.pillAutoRecordEnabled else {
            return nil
        }
        
        let pillCount = max(pillSettings.pillCount, 0)
        guard pillCount > 0 else { return nil }
        
        let calendar = Calendar.current
        let selected = selectedDate.startOfDay
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        ) else { return nil }
        
        let cycleStart = projection.cycleStart.startOfDay
        guard let intakeEnd = calendar.date(byAdding: .day, value: pillCount - 1, to: cycleStart)?.startOfDay else {
            return nil
        }
        guard selected >= cycleStart && selected <= intakeEnd else { return nil }
        
        let remainingCount = max(calendar.dateComponents([.day], from: selected, to: intakeEnd).day ?? 0, 0)
        guard remainingCount >= 1 else { return nil }
        
        let datesToDeleteFromSelected = Date.dates(from: selected, to: intakeEnd)
        return PillDisableConfirmationContext(
            remainingCount: remainingCount,
            datesToDeleteFromSelected: datesToDeleteFromSelected
        )
    }
    
    func deletePillEvents(on dates: [Date]) {
        for date in dates.map(\.startOfDay) {
            eventRepository.delete(type: .pill, on: date)
        }
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
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
        guard let bounds = calculationBounds(for: normalizedMonthDates) else {
            months = []
            currentIndex = 0
            return
        }
        let calculationEvents = calculationEvents(in: bounds)
        let context = buildMonthComputationContext(bounds: bounds, userEvents: calculationEvents)
        months = normalizedMonthDates.map { makeMonthInfo(for: $0, userEvents: calculationEvents, context: context) }
        
        if let idx = months.firstIndex(where: { $0.monthDate == keepingMonth.startOfMonth }) {
            currentIndex = idx
        } else {
            currentIndex = min(currentIndex, max(months.count - 1, 0))
        }
    }
    
    private func calculationBounds(for monthDates: [Date]) -> (start: Date, endExclusive: Date)? {
        guard let firstMonth = monthDates.min(),
              let lastMonth = monthDates.max() else {
            return nil
        }
        let start = firstMonth.startOfMonth.addingMonths(-1)
        let endExclusive = lastMonth.startOfMonth.addingMonths(2)
        return (start: start, endExclusive: endExclusive)
    }
    
    private func calculationEvents(in bounds: (start: Date, endExclusive: Date)) -> [UserEvent] {
        return eventRepository.allEvents().filter {
            let day = $0.date.startOfDay
            return day >= bounds.start && day < bounds.endExclusive
        }
    }
    
    private func buildMonthComputationContext(
        bounds: (start: Date, endExclusive: Date),
        userEvents: [UserEvent]
    ) -> MonthComputationContext {
        let settings = settingsRepository?.load() ?? .init()
        let today = Date().startOfDay
        let groupedEvents = Dictionary(grouping: userEvents) { $0.date.startOfDay }
        let eventsByDay = groupedEvents.mapValues { dayEvents in
            dayEvents.map { DayEvent(type: $0.type) }
        }
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: .current
        )
        let pillCycleRange = projectedPillCycleRangeForFertilitySuppression(
            settings: settings,
            projection: projection
        )
        let suppressFutureFertilityPrediction = shouldSuppressFutureFertilityPrediction(
            today: today,
            pillCycleRange: pillCycleRange
        )
        
        let pillSettings = settings.pill
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let pillSequenceByDate = PeriodForecastCalculator.pillSequenceMap(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: .current
        )
        
        let allPeriodEvents = eventRepository.events(of: .period)
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
        
        if let pillPrediction = pillBasedPeriodPrediction(
            rangeStart: bounds.start,
            rangeEndExclusive: bounds.endExclusive,
            settings: settings,
            projection: projection,
            today: today,
            predictedLengthDays: predictedPeriodLengthDays(settings: settings, periodSummaries: periodSummaries)
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
            for key in predictedEventsByDay.keys where key > today {
                var events = predictedEventsByDay[key] ?? []
                events.removeAll { $0 == .fertile || $0 == .ovulation }
                predictedEventsByDay[key] = events
            }
        }
        
        var predictedPeriodDates: Set<Date> = []
        for (date, types) in predictedEventsByDay where date >= bounds.start && date < bounds.endExclusive {
            if types.contains(.period) || types.contains(.delayed) {
                predictedPeriodDates.insert(date.startOfDay)
            }
        }
        
        return MonthComputationContext(
            eventsByDay: eventsByDay,
            pillDates: pillDates,
            pillSequenceByDate: pillSequenceByDate,
            predictedEventsByDay: predictedEventsByDay,
            predictedPeriodDates: predictedPeriodDates
        )
    }
    
    private func makeMonthInfo(for month: Date, userEvents: [UserEvent], context: MonthComputationContext) -> MonthInfo {
        let monthStart = month.startOfMonth
        let actualPeriodDates = Set(userEvents.filter { $0.type == .period }.map { $0.date.startOfDay })
        let result = buildDayInfos(for: monthStart, context: context)
        let days: [DayInfo] = result.days
        let predictedPeriodDates: Set<Date> = result.predictedPeriodDates
        
        let periodRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            actualPeriodDates.contains(day.date.startOfDay)
        }
        let predictedPeriodRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            predictedPeriodDates.contains(day.date.startOfDay)
        }
        let delayedRanges: [CalendarRangeInfo] = []
        let fertileRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            day.events.contains { $0.type == .fertile }
        }
        let rawOvulationRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            day.events.contains { $0.type == .ovulation }
        }
        let ovulationRanges: [CalendarRangeInfo] = rawOvulationRanges.map { ovulation in
            let ovulationDate = ovulation.range.start.startOfDay
            guard let fertileOpacity = fertileOpacity(containing: ovulationDate, fertileRanges: fertileRanges) else {
                return ovulation
            }
            return CalendarRangeInfo(range: ovulation.range, opacity: fertileOpacity)
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
        context: MonthComputationContext
    ) -> (days: [DayInfo], predictedPeriodDates: Set<Date>) {
        let gridStart = month.startOfCalendarGrid()
        let gridEndExclusive = month.endOfCalendarGridExclusiveStart()
        
        var days: [DayInfo] = Date.dates(from: gridStart, toExclusive: gridEndExclusive).map { DayInfo(date: $0) }
        
        for i in days.indices {
            let key = days[i].date.startOfDay
            let dayEvents: [DayEvent] = context.eventsByDay[key] ?? []
            days[i].events = dayEvents
        }
        
        let predictedPeriodDates = Set(
            context.predictedPeriodDates.filter { $0 >= gridStart && $0 < gridEndExclusive }
        )
        if !context.predictedEventsByDay.isEmpty {
            for i in days.indices {
                let key = days[i].date.startOfDay
                guard key >= gridStart && key < gridEndExclusive,
                      let predicted = context.predictedEventsByDay[key] else { continue }
                for type in predicted where !days[i].events.contains(where: { $0.type == type }) {
                    days[i].events.append(DayEvent(type: type))
                }
            }
        }
        
        for i in days.indices {
            let dayDate = days[i].date.startOfDay
            guard context.pillDates.contains(dayDate) else {
                days[i].pillSequence = nil
                continue
            }
            days[i].pillSequence = context.pillSequenceByDate[dayDate]
        }
        
        return (days, predictedPeriodDates)
    }
    
    private func pillBasedPeriodPrediction(
        rangeStart: Date,
        rangeEndExclusive: Date,
        settings: UserSettings,
        projection: PillCycleProjection?,
        today: Date,
        predictedLengthDays: Int
    ) -> [Date: [EventType]]? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        guard let projection else { return nil }
        let calendar = Calendar.current
        guard let firstPredictedStart = calendar.date(byAdding: .day, value: 3, to: projection.projectedLastIntakeDate),
              firstPredictedStart.startOfDay >= projection.cycleStart.startOfDay else {
            return nil
        }
        
        let normalizedStart = rangeStart.startOfDay
        let normalizedEnd = rangeEndExclusive.startOfDay
        let lengthDays = max(predictedLengthDays, 1)
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
    
    private func buildStyledRangesSplittingByWeeks(
        days: [DayInfo],
        monthDate: Date,
        hasEvent: (DayInfo) -> Bool,
        columns: Int = 7
    ) -> [CalendarRangeInfo] {
        var ranges: [CalendarRangeInfo] = []
        var idx = 0
        
        while idx < days.count {
            guard hasEvent(days[idx]) else {
                idx += 1
                continue
            }
            
            let runStartIndex = idx
            var runEndIndex = idx
            while runEndIndex + 1 < days.count && hasEvent(days[runEndIndex + 1]) {
                runEndIndex += 1
            }
            
            let runOpacity = opacityForRun(
                runStartDate: days[runStartIndex].date,
                runEndDate: days[runEndIndex].date,
                monthDate: monthDate
            )
            
            var segmentStartIndex = runStartIndex
            while segmentStartIndex <= runEndIndex {
                let rowEndIndex = ((segmentStartIndex / columns) * columns) + (columns - 1)
                let segmentEndIndex = min(runEndIndex, rowEndIndex)
                ranges.append(
                    CalendarRangeInfo(
                        range: DateInterval(start: days[segmentStartIndex].date, end: days[segmentEndIndex].date),
                        opacity: runOpacity
                    )
                )
                segmentStartIndex = segmentEndIndex + 1
            }
            
            idx = runEndIndex + 1
        }
        
        return ranges
    }
    
    private func opacityForRun(runStartDate: Date, runEndDate: Date, monthDate: Date) -> Double {
        let isOutsideCurrentMonth =
        !runStartDate.isInSameMonth(as: monthDate) &&
        !runEndDate.isInSameMonth(as: monthDate)
        return isOutsideCurrentMonth ? 0.3 : 1
    }
    
    private func fertileOpacity(containing date: Date, fertileRanges: [CalendarRangeInfo]) -> Double? {
        fertileRanges.first {
            date >= $0.range.start.startOfDay && date <= $0.range.end.startOfDay
        }?.opacity
    }
    
    private func projectedPillCycleRangeForFertilitySuppression(
        settings: UserSettings,
        projection: PillCycleProjection?
    ) -> DateInterval? {
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard cycleLength > 0 else { return nil }
        
        let calendar = Calendar.current
        guard let projection,
              let cycleEndExclusive = calendar.date(byAdding: .day, value: cycleLength, to: projection.cycleStart.startOfDay) else {
            return nil
        }
        
        return DateInterval(start: projection.cycleStart.startOfDay, end: cycleEndExclusive.startOfDay)
    }
    
    private func shouldSuppressFutureFertilityPrediction(
        today: Date,
        pillCycleRange: DateInterval?
    ) -> Bool {
        guard let pillCycleRange else { return false }
        return today >= pillCycleRange.start.startOfDay && today < pillCycleRange.end.startOfDay
    }
    
    private func predictedPeriodLengthDays(
        settings: UserSettings,
        periodSummaries: [PeriodSummary]
    ) -> Int {
        return PeriodForecastCalculator.predictedPeriodLengthDays(
            settings: settings,
            periodSummaries: periodSummaries
        )
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
            let lengthDays = predictedPeriodLengthDaysFromCurrentData()
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
        guard pillCount > 0 else { return }
        
        let calendar = Calendar.current
        let start = date.startOfDay
        var pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        var cycleDates = cyclePillDates(containing: start, pillDates: pillDates, pillCount: pillCount, breakDays: breakDays, calendar: calendar)
        guard cycleDates.count < pillCount else {
            if eventRepository.events(of: .pill).contains(where: { $0.date.startOfDay == start }) == false {
                eventRepository.save(UserEvent(id: .init(), date: start, type: .pill))
            }
            return
        }
        
        var cursor = start
        while cycleDates.count < pillCount {
            if pillDates.contains(cursor) == false {
                let new = UserEvent(id: .init(), date: cursor, type: .pill)
                eventRepository.save(new)
                pillDates.insert(cursor)
                cycleDates = cyclePillDates(containing: start, pillDates: pillDates, pillCount: pillCount, breakDays: breakDays, calendar: calendar)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next.startOfDay
        }
    }
    
    private func cyclePillDates(
        containing target: Date,
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar
    ) -> Set<Date> {
        let cycles = groupedPillCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        
        let normalizedTarget = target.startOfDay
        guard let cycle = cycles.first(where: { $0.contains(normalizedTarget) }) else {
            return [normalizedTarget]
        }
        return Set(cycle)
    }
    
    private func groupedPillCycles(
        pillDates: Set<Date>,
        pillCount: Int,
        breakDays: Int,
        calendar: Calendar
    ) -> [[Date]] {
        let sorted = pillDates.map(\.startOfDay).sorted()
        guard sorted.isEmpty == false else { return [] }
        
        let allowedGap = max(breakDays, 0) + 1
        var cycles: [[Date]] = [[sorted[0]]]
        
        for day in sorted.dropFirst() {
            guard var current = cycles.last else { continue }
            guard let previous = current.last else { continue }
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? .max
            
            let shouldStartNewCycle = current.count >= pillCount || gap > allowedGap
            if shouldStartNewCycle {
                cycles.append([day])
            } else {
                current.append(day)
                cycles[cycles.count - 1] = current
            }
        }
        
        return cycles
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
        let today = Date().startOfDay
        
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
        
        let settings = settingsRepository?.load() ?? .init()
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let context = PeriodForecastCalculator.predictionContext(
            target: target,
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            calendar: calendar
        ),
              let predictedStart = PeriodForecastCalculator.expectedStartDate(
                target: target,
                today: today,
                context: context,
                calendar: calendar
              ) else {
            return .unknown
        }
        let predictedLength = max(context.predictedLength, 1)
        let predictedEndExclusive = calendar.date(byAdding: .day, value: predictedLength, to: predictedStart.startOfDay)!
        
        if target == predictedStart.startOfDay {
            return .bDay
        }
        if target > predictedStart.startOfDay && target < predictedEndExclusive {
            let dayIndex = (calendar.dateComponents([.day], from: predictedStart.startOfDay, to: target).day ?? 0) + 1
            return .ongoing(day: max(dayIndex, 1))
        }
        if target >= predictedStart && target <= today {
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
        
        if shouldShowPillStatus, let scheduled = scheduledPillStatusForCurrentCycle(for: date) {
            return scheduled
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
    
    private func predictedPeriodLengthDaysFromCurrentData() -> Int {
        let settings = settingsRepository?.load() ?? .init()
        return PeriodForecastCalculator.predictedPeriodLengthDays(
            settings: settings,
            periodSummaries: actualPeriodSummaries()
        )
    }
    
    private func manualCycleAverages(for settings: UserSettings) -> (cycleDays: Int?, periodDays: Int?) {
        let periodSettings = settings.period
        guard periodSettings.autoCyclePredictionEnabled == false else {
            return (nil, nil)
        }
        return (periodSettings.averageCycleDays, periodSettings.averagePeriodDays)
    }
    
    private func pillInfo(for date: Date) -> (day: Int, total: Int?)? {
        guard let pillSettings = settingsRepository?.load().pill else { return nil }
        guard pillSettings.pillEnabled else { return nil }
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let target = date.startOfDay
        guard pillDates.contains(target) else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let sequenceByDate = PeriodForecastCalculator.pillSequenceMap(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: .current
        )
        guard let sequence = sequenceByDate[target] else { return nil }
        return (day: sequence, total: pillCount > 0 ? pillCount : nil)
    }
    
    private func pillBreakInfo(for date: Date) -> (day: Int, total: Int)? {
        guard let pillSettings = settingsRepository?.load().pill else { return nil }
        guard pillSettings.pillEnabled else { return nil }
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let autoRecordEnabled = pillSettings.pillAutoRecordEnabled
        guard pillCount > 0, breakDays > 0 else { return nil }
        
        let calendar = Calendar.current
        let target = date.startOfDay
        
        if autoRecordEnabled == false {
            let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
            guard let projection = PeriodForecastCalculator.latestPillCycleProjection(
                settings: settingsRepository?.load() ?? .init(),
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
        
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let cycles = groupedPillCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        
        for cycle in cycles {
            guard let lastIntake = cycle.last else {
                continue
            }
            let projectedLast = lastIntake.startOfDay
            guard let breakStart = calendar.date(byAdding: .day, value: 1, to: projectedLast),
                  let breakEndExclusive = calendar.date(byAdding: .day, value: breakDays, to: breakStart.startOfDay) else {
                continue
            }
            guard target >= breakStart.startOfDay && target < breakEndExclusive.startOfDay else {
                continue
            }
            let breakDay = (calendar.dateComponents([.day], from: breakStart.startOfDay, to: target).day ?? 0) + 1
            return (day: breakDay, total: breakDays)
        }
        
        return nil
    }
    
    private func scheduledPillStatusForCurrentCycle(for date: Date) -> CalendarSecondaryStatus? {
        let settings = settingsRepository?.load() ?? .init()
        let pillSettings = settings.pill
        guard pillSettings.pillEnabled else { return nil }
        
        let pillCount = max(pillSettings.pillCount, 0)
        let breakDays = max(pillSettings.pillBreakDuration, 0)
        let cycleLength = pillCount + breakDays
        guard pillCount > 0, cycleLength > 0 else { return nil }
        
        let calendar = Calendar.current
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        ) else { return nil }
        
        let target = date.startOfDay
        
        if pillSettings.pillAutoRecordEnabled {
            guard let cycleEndExclusive = calendar.date(byAdding: .day, value: cycleLength, to: projection.cycleStart.startOfDay),
                  target >= projection.cycleStart.startOfDay,
                  target < cycleEndExclusive.startOfDay else {
                return nil
            }
            
            let index = calendar.dateComponents([.day], from: projection.cycleStart.startOfDay, to: target).day ?? -1
            guard index >= 0 else { return nil }
            
            if index < pillCount {
                return .pill(day: index + 1, total: pillCount)
            }
            let breakDay = index - pillCount + 1
            guard breakDays > 0, breakDay > 0, breakDay <= breakDays else { return nil }
            return .pillBreak(day: breakDay, total: breakDays)
        }
        
        let cycles = groupedPillCycles(
            pillDates: pillDates,
            pillCount: pillCount,
            breakDays: breakDays,
            calendar: calendar
        )
        guard let currentCycle = cycles.last,
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
