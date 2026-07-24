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
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.pillCycleID = pillCycleID
        self.uniqueKey = Self.makeUniqueKey(date: date, type: type, calendar: calendar)
        self.date = calendar.startOfDay(for: date)
    }
    
    static func makeUniqueKey(date: Date, type: EventType, calendar: Calendar) -> String {
        let calendarDay = CalendarDay(date: date, calendar: calendar)
        return "\(calendarDay.dayKey)|\(type.rawValue)"
    }

    var calendarDay: CalendarDay? {
        uniqueKey
            .split(separator: "|")
            .first
            .flatMap { Int($0) }
            .flatMap(CalendarDay.init(dayKey:))
    }

    func resolvedDate(
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        guard let calendarDay,
              let resolved = calendarDay.date(in: calendar) else {
            return calendar.startOfDay(for: date)
        }
        return resolved
    }

    func resolvedCopy(
        calendar: Calendar = .autoupdatingCurrent
    ) -> UserEvent {
        let copy = UserEvent(
            id: id,
            date: resolvedDate(calendar: calendar),
            type: type,
            pillCycleID: pillCycleID,
            calendar: calendar
        )
        copy.uniqueKey = uniqueKey
        return copy
    }

    @discardableResult
    func normalizeDate(
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let resolved = resolvedDate(calendar: calendar)
        guard date != resolved else { return false }
        date = resolved
        return true
    }
}
