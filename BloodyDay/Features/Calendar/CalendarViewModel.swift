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
    
    // Derived days for the 6x7 grid
    var days: [DayInfo] {
        let start = currentMonthStart.startOfCalendarGrid()
        return (0..<42).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayInfo(date: date)
        }
    }
    
    init(referenceDate: Date = .now) {
        // Initialize to current month based on reference date
        self.currentMonthStart = referenceDate
    }
    
    // Placeholder for future month navigation
    func goToPreviousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthStart) {
            currentMonthStart = newDate
        }
    }
    
    func goToNextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonthStart) {
            currentMonthStart = newDate
        }
    }
}
