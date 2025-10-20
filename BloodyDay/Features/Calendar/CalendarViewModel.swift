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
    var currentMonthStart: Date
    var selectedDate: Date = .now
    
    var days: [DayInfo] {
        let start = currentMonthStart.startOfCalendarGrid()
        return (0..<42).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayInfo(date: date)
        }
    }
    
    init(referenceDate: Date = .now) {
        self.currentMonthStart = referenceDate
    }
}
