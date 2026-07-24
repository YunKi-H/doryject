//
//  UserEvent.swift
//  BloodyDay
//
//  Created by Yunki on 10/21/25.
//

import Foundation
import SwiftData

@Model
final class UserEvent {
    var id: UUID
    var date: Date
    var typeRaw: String
    var pillCycleID: UUID?
    
    var type: EventType {
        get { EventType(rawValue: typeRaw)! }
        set { typeRaw = newValue.rawValue }
    }
    
    @Attribute(.unique)
    var uniqueKey: String
    
    init(
        id: UUID = .init(),
        date: Date,
        type: EventType,
        pillCycleID: UUID? = nil,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.pillCycleID = pillCycleID
        self.uniqueKey = Self.makeUniqueKey(date: date, type: type, calendar: calendar)
        self.date = calendar.startOfDay(for: date)
    }
    
    static func makeUniqueKey(date: Date, type: EventType, calendar: Calendar) -> String {
        let civilCalendar = civilCalendar(timeZone: calendar.timeZone)
        let comps = civilCalendar.dateComponents([.year, .month, .day], from: date)
        let dayKey = (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
        return "\(dayKey)|\(type.rawValue)"
    }

    func resolvedDate(calendar: Calendar = .current) -> Date {
        guard let dayKey = uniqueKey.split(separator: "|").first.flatMap({ Int($0) }) else {
            return calendar.startOfDay(for: date)
        }

        let year = dayKey / 10_000
        let month = (dayKey / 100) % 100
        let day = dayKey % 100
        let components = DateComponents(year: year, month: month, day: day)
        let civilCalendar = Self.civilCalendar(timeZone: calendar.timeZone)
        guard let resolved = civilCalendar.date(from: components) else {
            return calendar.startOfDay(for: date)
        }
        let resolvedComponents = civilCalendar.dateComponents(
            [.year, .month, .day],
            from: resolved
        )
        guard resolvedComponents.year == year,
              resolvedComponents.month == month,
              resolvedComponents.day == day else {
            return calendar.startOfDay(for: date)
        }
        return civilCalendar.startOfDay(for: resolved)
    }

    @discardableResult
    func normalizeDate(calendar: Calendar = .current) -> Bool {
        let resolved = resolvedDate(calendar: calendar)
        guard date != resolved else { return false }
        date = resolved
        return true
    }

    private static func civilCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}
