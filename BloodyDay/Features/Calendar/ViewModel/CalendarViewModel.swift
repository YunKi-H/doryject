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

extension CalendarViewModel {
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
        let events = eventRepository.allEvents()
        let cycles = cycleAnalyzer.analyze(from: events.map { $0.date })

        let rule = cyclePredictor.makeRule(from: cycles)
        let visibleRange = DateInterval(start: monthStart.startOfCalendarGrid(),
                                        end: monthStart.endOfCalendarGridExclusiveStart())
        let predictedCycles = rule == nil ? [] : cyclePredictor.predictPeriods(using: rule!, in: visibleRange)

        let days = buildDayInfos(for: monthStart, cycles: cycles, predictedPeriods: predictedCycles, userEvents: events)

        // 필요하다면 ranges도 month 경계로 클리핑/매핑
        let periodRanges: [DateInterval] = []      // TODO: cycles -> DateInterval 변환
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
        trimIfNeeded()
    }

    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = makeMonthInfo(for: last.addingMonths(+1))
        months.append(next)
        trimIfNeeded()
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
