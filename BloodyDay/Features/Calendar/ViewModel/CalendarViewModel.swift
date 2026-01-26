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
        bootstrapMonths(anchor: selectedDate)
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
            eventRepository.delete(type: type, on: date)
        }
        let anchorMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : date
        bootstrapMonths(anchor: anchorMonth)
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
            loadPreviousIfNeeded(viewingIndex: idx)
            loadNextIfNeeded(viewingIndex: idx)
        } else {
            bootstrapMonths(anchor: start)
        }
    }
    
    private func loadPreviousIfNeeded(viewingIndex index: Int) {
        guard index <= 1, let first = months.first?.monthDate else { return }
        let prev = makeMonthInfo(for: first.addingMonths(-1))
        months.insert(prev, at: 0)
        currentIndex += 1
    }
    
    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = makeMonthInfo(for: last.addingMonths(+1))
        months.append(next)
    }
    
    private func bootstrapMonths(anchor: Date) {
        let prev = makeMonthInfo(for: anchor.addingMonths(-1))
        let current = makeMonthInfo(for: anchor)
        let next = makeMonthInfo(for: anchor.addingMonths(1))
        months = [prev, current, next]
        currentIndex = 1
    }
    
    private func makeMonthInfo(for month: Date) -> MonthInfo {
        let monthStart = month.startOfMonth
        let allEvents = eventRepository.allEvents()
        let days: [DayInfo] = buildDayInfos(for: month, userEvents: allEvents)
        
        let periodRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            day.events.contains { $0.type == .period }
        }
        let delayedRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            day.events.contains { $0.type == .delayed }
        }
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
            delayedRanges: delayedRanges,
            fertileRanges: fertileRanges,
            ovulationRanges: ovulationRanges
        )
    }
    
    private func buildDayInfos(
        for month: Date,
        userEvents: [UserEvent]
    ) -> [DayInfo] {
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
        
        if !prediction.predictedEventsByDay.isEmpty {
            for i in days.indices {
                let key = days[i].date.startOfDay
                guard let predicted = prediction.predictedEventsByDay[key] else { continue }
                for type in predicted where !days[i].events.contains(where: { $0.type == type }) {
                    days[i].events.append(DayEvent(type: type))
                }
            }
        }
        
        let calendar = Calendar.current
        let pillDates = Set(userEvents.filter { $0.type == .pill }.map { $0.date.startOfDay })
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
        var pillStreak = 0
        var cursor = calendar.date(byAdding: .day, value: -1, to: gridStart.startOfDay)!
        while allPillDates.contains(cursor) {
            pillStreak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        
        for i in days.indices {
            let dayDate = days[i].date.startOfDay
            if allPillDates.contains(dayDate) {
                pillStreak += 1
                days[i].pillSequence = pillStreak
            } else {
                pillStreak = 0
                days[i].pillSequence = nil
            }
        }
        
        return days
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
    
    private var shouldAutoRecordPill: Bool {
        settingsRepository?.load().pill.pillAutoRecordEnabled == true
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
    var primaryStatus: CalendarPrimaryStatus {
        periodStatus(for: .now)
    }
    
    var secondaryStatus: CalendarSecondaryStatus {
        secondaryStatus(for: .now)
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
        if target >= predictedStart {
            return .delayed(days: max(calendar.dateComponents([.day], from: predictedStart.startOfDay, to: target).day ?? 0, 0))
        }
        
        let daysUntil = calendar.dateComponents([.day], from: target, to: predictedStart).day ?? 0
        return .countdown(days: max(daysUntil, 0))
    }
    
    private func secondaryStatus(for date: Date) -> CalendarSecondaryStatus {
        if eventRepository.allEvents().isEmpty {
            return .unknown
        }
        guard let dayInfo = months
            .flatMap(\.days)
            .first(where: { $0.date.isSameDay(as: date) }) else {
            return .notFertile
        }
        
        if let pillSequence = dayInfo.pillSequence {
            let total = settingsRepository?.load().pill.pillCount
            return .pill(day: pillSequence, total: total)
        }

        if let breakInfo = pillBreakInfo(for: date) {
            return .pillBreak(day: breakInfo.day, total: breakInfo.total)
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

    private func pillBreakInfo(for date: Date) -> (day: Int, total: Int)? {
        guard let pillSettings = settingsRepository?.load().pill,
              pillSettings.pillEnabled else { return nil }
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
    case delayed(days: Int)
    case unknown
    
    var displayText: String {
        switch self {
        case .countdown(let days):
            return "B-\(days)"
        case .ongoing(let day):
            return "B+\(day)"
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
        case .pillBreak(let day, let total):
            return "휴약기 (\(day)일째/\(total)일)"
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
        case .ovulation:
            return "(배란일)"
        case .fertile:
            return "(가임기)"
        default:
            return nil
        }
    }
}
