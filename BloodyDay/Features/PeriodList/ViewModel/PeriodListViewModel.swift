//
//  PeriodListViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 12/13/25.
//

import Foundation
import Observation

@Observable
final class PeriodListViewModel {
    private let eventRepository: EventRepository
    private let formatter: DateFormatter
    
    private(set) var summaries: [PeriodSummary] = []
    
    init(eventRepository: EventRepository, formatter: DateFormatter = .periodList) {
        self.eventRepository = eventRepository
        self.formatter = formatter
        refresh()
    }
    
    func refresh() {
        let events = eventRepository.events(of: .period)
        summaries = PeriodSummaryBuilder.build(from: events.map { $0.date })
    }

    func periodDates() -> Set<Date> {
        Set(eventRepository.events(of: .period).map { $0.date.startOfDay })
    }

    func applyPeriodDates(_ dates: Set<Date>) {
        let existing = periodDates()
        let toAdd = dates.subtracting(existing)
        let toRemove = existing.subtracting(dates)

        for day in toAdd {
            let new = UserEvent(id: .init(), date: day.startOfDay, type: .period)
            eventRepository.save(new)
        }

        for day in toRemove {
            eventRepository.delete(type: .period, on: day.startOfDay)
        }

        refresh()
    }

    func delete(summary: PeriodSummary) {
        let start = summary.start.startOfDay
        let end = summary.end.startOfDay
        for day in Date.dates(from: start, to: end) {
            eventRepository.delete(type: .period, on: day)
        }
        refresh()
    }
    
    var lastPeriodStartDisplay: String {
        guard let lastStart = summaries.last?.start else { return "-" }
        let calendar = Calendar.current
        let today = Date().startOfDay
        let start = lastStart.startOfDay
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return "\(max(days, 0))일 전"
    }
    
    var lastPeriodRangeDisplay: String {
        guard let last = summaries.last else { return "기록 없음" }
        return "\(format(last.start)) - \(format(last.end))"
    }
    
    var averagePeriodDisplay: String {
        let lengths = summaries.map(\.lengthDays)
        guard !lengths.isEmpty else { return "-" }
        let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
        return "\(Int(round(avg)))일"
    }
    
    var averageCycleDisplay: String {
        let cycles = summaries.compactMap(\.cycleDays)
        guard !cycles.isEmpty else { return "-" }
        let avg = Double(cycles.reduce(0, +)) / Double(cycles.count)
        return "\(Int(round(avg)))일"
    }
    
    func format(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
