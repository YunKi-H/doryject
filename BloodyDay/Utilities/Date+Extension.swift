//
//  Date+Extension.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import Foundation

enum Weekday: Int {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

extension Date {
    private var calendar: Calendar { Calendar.current }
    
    func component(_ component: Calendar.Component) -> Int {
        calendar.component(component, from: self)
    }

    // MARK: - Day normalization & comparison
    var startOfDay: Date { calendar.startOfDay(for: self) }

    var endOfDay: Date {
        let start = startOfDay
        // Add one day then subtract one second to get the end of current day
        return calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
    }

    func isSameDay(as other: Date) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }

    var isToday: Bool {
        calendar.isDateInToday(self)
    }

    func isInSameMonth(as other: Date) -> Bool {
        calendar.component(.year, from: self) == calendar.component(.year, from: other) &&
        calendar.component(.month, from: self) == calendar.component(.month, from: other)
    }

    // MARK: - Month boundaries
    var startOfMonth: Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps)!.startOfDay
    }

    var endOfMonth: Date {
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return calendar.date(byAdding: comps, to: startOfMonth)!.endOfDay
    }

    // MARK: - Calendar grid range (for month view)
    func startOfCalendarGrid(weekStartsOn firstWeekday: Weekday = .monday) -> Date {
        var cal = calendar
        cal.firstWeekday = firstWeekday.rawValue
        let firstOfMonth = startOfMonth
        let weekday = cal.component(.weekday, from: firstOfMonth)
        let delta = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -delta, to: firstOfMonth)!.startOfDay
    }

    /// Exclusive upper bound for the calendar grid (start of the day after the last cell)
    func endOfCalendarGridExclusiveStart(weekStartsOn firstWeekday: Weekday = .monday) -> Date {
        var cal = calendar
        cal.firstWeekday = firstWeekday.rawValue
        let startOfCalendarGrid = self.startOfCalendarGrid(weekStartsOn: firstWeekday)
        return cal.date(byAdding: .day, value: 42, to: startOfCalendarGrid)!.startOfDay
    }

    func endOfCalendarGrid(weekStartsOn firstWeekday: Weekday = .monday) -> Date {
        // Backward compatible: keep returning the last day's end-of-day
        // but compute via exclusive-start helper minus 1 second.
        let exclusiveStart = endOfCalendarGridExclusiveStart(weekStartsOn: firstWeekday)
        return exclusiveStart.addingTimeInterval(-1)
    }

    // MARK: - Sequence utility
    static func dates(from start: Date, to end: Date, step component: Calendar.Component = .day) -> [Date] {
        var result: [Date] = []
        var current = start
        let cal = Calendar.current
        while current <= end {
            result.append(current)
            current = cal.date(byAdding: component, value: 1, to: current)!
        }
        return result
    }

    // Half-open interval version: [start, endExclusive)
    static func dates(from start: Date, toExclusive endExclusive: Date, step component: Calendar.Component = .day) -> [Date] {
        var result: [Date] = []
        var current = start
        let cal = Calendar.current
        while current < endExclusive {
            result.append(current)
            current = cal.date(byAdding: component, value: 1, to: current)!
        }
        return result
    }
    
    // MARK: - Controls
    func addingMonths(_ month: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: month, to: self)!
    }
}
