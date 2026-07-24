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
    private let calendar: Calendar
    
    private(set) var summaries: [PeriodSummary] = []
    
    init(
        eventRepository: EventRepository,
        formatter: DateFormatter = .periodList,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.eventRepository = eventRepository
        self.formatter = formatter
        self.calendar = calendar
        refresh()
    }
    
    func refresh() {
        let events = eventRepository.events(of: .period)
        summaries = PeriodSummaryBuilder.build(
            from: events.map(\.date),
            calendar: calendar
        )
    }
    
    func periodDates() -> Set<Date> {
        Set(eventRepository.events(of: .period).map {
            calendar.startOfDay(for: $0.date)
        })
    }
    
    func applyPeriodDates(_ dates: Set<Date>) {
        let normalized = Set(dates.map { calendar.startOfDay(for: $0) })
        eventRepository.replace(type: .period, on: normalized)
        refresh()
    }
    
    func delete(summary: PeriodSummary) {
        let start = calendar.startOfDay(for: summary.start)
        let end = calendar.startOfDay(for: summary.end)
        let toRemove = Set(
            Date.dates(
                from: start,
                to: end,
                calendar: calendar
            ).map { calendar.startOfDay(for: $0) }
        )
        let remaining = periodDates().subtracting(toRemove)
        eventRepository.replace(type: .period, on: remaining)
        refresh()
    }
    
    var lastPeriodStartDisplay: String {
        guard let lastStart = summaries.map(\.start).max() else { return "-" }
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: lastStart)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return "\(max(days, 0))일 전"
    }
    
    var lastPeriodStartDateDisplay: String {
        guard let lastStart = summaries.map(\.start).max() else { return "기록 없음" }
        return format(lastStart)
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
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
    
    func rangeDisplay(start: Date, end: Date) -> String {
        let startComp = calendar.dateComponents([.year, .month, .day], from: start)
        let endComp = calendar.dateComponents([.year, .month, .day], from: end)
        let startText = format(start)
        
        let endText: String
        if startComp.year == endComp.year {
            if startComp.month == endComp.month {
                endText = "\(endComp.day ?? 0)일"
            } else {
                endText = "\(endComp.month ?? 0)월 \(endComp.day ?? 0)일"
            }
        } else {
            endText = format(end)
        }
        
        return "\(startText) - \(endText)"
    }
}
