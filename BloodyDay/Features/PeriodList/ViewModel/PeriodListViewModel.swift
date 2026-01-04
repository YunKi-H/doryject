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
    
    var lastPeriodStartDisplay: String {
        guard let lastStart = summaries.last?.start else { return "-" }
        return format(lastStart)
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
