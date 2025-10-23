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
    var selectedDate: Date = .now {
        didSet { reloadDays(for: selectedDate) }
    }
    
    var days: [DayInfo] = []
    
    private let eventRepository: EventRepository
    private let cycleAnalyzer: CycleAnalyzer
    private let cyclePredictor: CyclePredictor
    
    init(eventRepository: EventRepository, cycleAnalyzer: CycleAnalyzer, cyclePredictor: CyclePredictor) {
        self.eventRepository = eventRepository
        self.cycleAnalyzer = cycleAnalyzer
        self.cyclePredictor = cyclePredictor
        
        reloadDays(for: selectedDate)
    }
}

extension CalendarViewModel {
    private func reloadDays(for month: Date) {
        let events = eventRepository.allEvents()
        let cycles = cycleAnalyzer.analyze(from: events.map { $0.date })
        
        let rule = cyclePredictor.makeRule(from: cycles)
        let range = DateInterval(start: month.startOfCalendarGrid(), end: month.endOfCalendarGridExclusiveStart())
        let predictedCycles = rule == nil ? [] : cyclePredictor.predictPeriods(using: rule!, in: range)
        
        self.days = buildDayInfos(for: month, cycles: cycles, predictedPeriods: predictedCycles, userEvents: events)
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
