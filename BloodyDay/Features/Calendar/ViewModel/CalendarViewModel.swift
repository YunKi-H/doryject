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
    private let cycleAnalyzer: CycleAnalyzer
    private let cyclePredictor: CyclePredictor
    
    init(eventRepository: EventRepository, cycleAnalyzer: CycleAnalyzer, cyclePredictor: CyclePredictor) {
        self.eventRepository = eventRepository
        self.cycleAnalyzer = cycleAnalyzer
        self.cyclePredictor = cyclePredictor
        
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

        for type in toAdd {
            let new = UserEvent(id: .init(), date: date, type: type)
            eventRepository.save(new)
        }
        for type in toRemove {
            eventRepository.delete(type: type, on: date)
        }
        months[currentIndex] = makeMonthInfo(for: date)
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
    
    private func bootstrapMonths(anchor: Date) {
        let prev = makeMonthInfo(for: anchor.addingMonths(-1))
        let current = makeMonthInfo(for: anchor)
        let next = makeMonthInfo(for: anchor.addingMonths(1))
        months = [prev, current, next]
        currentIndex = 1
    }
    
    private func makeMonthInfo(for month: Date) -> MonthInfo {
        let monthStart = month.startOfMonth
        
        let gridStart = monthStart.startOfCalendarGrid()
        let gridEndExclusive = monthStart.endOfCalendarGridExclusiveStart()
        
        let gridDates = Date.dates(from: gridStart, to: gridEndExclusive)
        var days: [DayInfo] = gridDates.map { DayInfo(date: $0) }
        
        let allEvents = eventRepository.allEvents()
        let periodEvents: [UserEvent] = allEvents.filter {
            $0.type == .period && gridStart..<gridEndExclusive ~= $0.date
        }
        
        let eventsByDay = Dictionary(grouping: periodEvents) { $0.date.startOfDay }
        for i in days.indices {
            let key = days[i].date.startOfDay
            let dayEvents: [DayEvent] = eventsByDay[key]?.map { DayEvent(type: $0.type) } ?? []
            days[i].events = dayEvents
        }
        
        // Build period ranges from days, merging contiguous period days but splitting at week boundaries
        let columns = 7
        var ranges: [DateInterval] = []
        var currentStart: Date? = nil
        var lastIndex: Int? = nil
        for idx in days.indices {
            let day = days[idx]
            let hasPeriod = day.events.contains { $0.type == .period }
            if hasPeriod {
                if currentStart == nil {
                    currentStart = day.date
                    lastIndex = idx
                } else {
                    // If the previous index was Sunday (col 6) and now moved to next index, split at week boundary
                    if let li = lastIndex, li % columns == columns - 1 {
                        // close previous range at previous day
                        let endDate = days[li].date
                        ranges.append(DateInterval(start: currentStart!, end: endDate))
                        // start new range at this day
                        currentStart = day.date
                    }
                    lastIndex = idx
                }
            } else if let li = lastIndex, let start = currentStart {
                // close ongoing range when period streak ends
                let endDate = days[li].date
                ranges.append(DateInterval(start: start, end: endDate))
                currentStart = nil
                lastIndex = nil
            } else {
                // no active range and no period; continue
            }
        }
        // close tail range if still open
        if let li = lastIndex, let start = currentStart {
            let endDate = days[li].date
            ranges.append(DateInterval(start: start, end: endDate))
        }
        print(ranges)
        let periodRanges: [DateInterval] = ranges      // TODO: cycles -> DateInterval 변환
        
        let predictedRanges: [DateInterval] = []   // TODO: predictedCycles -> DateInterval 변환
        let fertileRanges: [DateInterval] = []     // TODO
        let ovulationRanges: [DateInterval] = []   // TODO

        return MonthInfo(
            monthDate: monthStart,
            days: days,
            periodRanges: periodRanges,
            predictedRanges: predictedRanges,
            fertileRanges: fertileRanges,
            ovulationRanges: ovulationRanges
        )
    }
    
    private func loadPreviousIfNeeded(viewingIndex index: Int) {
        guard index <= 1, let first = months.first?.monthDate else { return }
        let prev = makeMonthInfo(for: first.addingMonths(-1))
        months.insert(prev, at: 0)
        currentIndex += 1
//        trimIfNeeded()
    }

    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = makeMonthInfo(for: last.addingMonths(+1))
        months.append(next)
//        trimIfNeeded()
    }

    private func trimIfNeeded(maxMonths: Int = 7) {
        guard months.count > maxMonths else { return }
        // 양 끝에서 제거하되 currentIndex 보정
        while months.count > maxMonths {
            if currentIndex > maxMonths / 2 {
                currentIndex -= 1
                months.removeFirst()
            } else {
                months.removeLast()
            }
        }
    }
    
    private func buildDayInfos(
        for month: Date,
        cycles: [CycleRecord],
        predictedPeriods: [PredictedPeriod],
        userEvents: [UserEvent]
    ) -> [DayInfo] {
        let start = month.startOfCalendarGrid()
        
        // TODO: - Logic
        
        return (0..<42).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayInfo(date: date)
        }
    }
}
