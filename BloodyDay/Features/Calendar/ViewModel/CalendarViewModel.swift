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
    
    init(eventRepository: EventRepository) {
        self.eventRepository = eventRepository
        
        bootstrapMonths(anchor: selectedDate)
    }

    var primaryStatusText: String {
        periodStatusText(for: .now)
    }

    var secondaryStatusText: String {
        secondaryStatusText(for: .now)
    }

    func refresh() {
        bootstrapMonths(anchor: selectedDate)
    }
}

// Repository
extension CalendarViewModel {
    func isEventOnSelectedDate(_ type: EventType) -> Bool {
        let thisMonth = months[currentIndex]
        guard let todayInfo = thisMonth.days.first(where: { $0.date.isSameDay(as: selectedDate) })
        else { return false }
        return todayInfo.events.contains {
            $0.type == type
        }
    }
    
    func commitEventsForSelectedDate(from initial: Set<EventType>, to final: Set<EventType>) {
        let date = selectedDate.startOfDay
        
        let toAdd = final.subtracting(initial)
        let toRemove = initial.subtracting(final)
        
        if toAdd.contains(.period) {
            addPeriodEvents(startingAt: date)
        }
        for type in toAdd where type != .period {
            let new = UserEvent(id: .init(), date: date, type: type)
            eventRepository.save(new)
        }
        for type in toRemove {
            eventRepository.delete(type: type, on: date)
        }
        bootstrapMonths(anchor: date)
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
        selectedDate = start
        
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
        let prediction = CyclePrediction.predictEvents(
            periodEvents: periodEvents,
            rangeStart: gridStart,
            rangeEndExclusive: gridEndExclusive
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
        var pillStreak = 0
        var cursor = calendar.date(byAdding: .day, value: -1, to: gridStart.startOfDay)!
        while pillDates.contains(cursor) {
            pillStreak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        
        for i in days.indices {
            let dayDate = days[i].date.startOfDay
            if pillDates.contains(dayDate) {
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
            let endExclusive = calendar.date(byAdding: .day, value: 5, to: normalizedDate)!
            datesToAdd = Date.dates(from: normalizedDate, toExclusive: endExclusive)
        }
        
        for day in datesToAdd {
            let new = UserEvent(id: .init(), date: day, type: .period)
            eventRepository.save(new)
        }
    }

    private func periodStatusText(for date: Date) -> String {
        let summaries = actualPeriodSummaries()
        let calendar = Calendar.current
        let target = date.startOfDay

        if let ongoing = summaries.first(where: { $0.start.startOfDay <= target && target <= $0.end.startOfDay }) {
            let dayIndex = (calendar.dateComponents([.day], from: ongoing.start.startOfDay, to: target).day ?? 0) + 1
            return "B+\(max(dayIndex, 1))"
        }

        guard let avgCycle = averageCycleDays(from: summaries),
              let lastStart = summaries.last?.start.startOfDay else {
            return "-"
        }

        let predictedStart = calendar.date(byAdding: .day, value: avgCycle, to: lastStart)!
        if target >= predictedStart {
            return "생리 지연"
        }

        let daysUntil = calendar.dateComponents([.day], from: target, to: predictedStart).day ?? 0
        return "B-\(max(daysUntil, 0))"
    }

    private func secondaryStatusText(for date: Date) -> String {
        guard let dayInfo = months
            .flatMap(\.days)
            .first(where: { $0.date.isSameDay(as: date) }) else {
            return "가임기 아님"
        }

        if let pillSequence = dayInfo.pillSequence {
            return "피임약 \(pillSequence)일째"
        }

        if dayInfo.events.contains(where: { $0.type == .ovulation }) {
            return "배란일"
        }

        if dayInfo.events.contains(where: { $0.type == .fertile }) {
            return "가임기"
        }

        return "가임기 아님"
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
}
