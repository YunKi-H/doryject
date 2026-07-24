//
//  CalendarDay.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation

struct CalendarDay: Codable, Comparable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar) {
        let calendar = Self.gregorianCalendar(timeZone: calendar.timeZone)
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            preconditionFailure("Unable to resolve a civil calendar day")
        }
        self.year = year
        self.month = month
        self.day = day
    }

    init?(year: Int, month: Int, day: Int) {
        let calendar = Self.gregorianCalendar(
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let components = DateComponents(
            year: year,
            month: month,
            day: day
        )
        guard let date = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    init?(dayKey: Int) {
        guard dayKey > 0 else { return nil }
        self.init(
            year: dayKey / 10_000,
            month: (dayKey / 100) % 100,
            day: dayKey % 100
        )
    }

    var dayKey: Int {
        year * 10_000 + month * 100 + day
    }

    var dateString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func date(in calendar: Calendar) -> Date? {
        let calendar = Self.gregorianCalendar(timeZone: calendar.timeZone)
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ) else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.dayKey < rhs.dayKey
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
