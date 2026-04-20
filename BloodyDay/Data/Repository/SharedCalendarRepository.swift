//
//  SharedCalendarRepository.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

protocol SharedCalendarRepository {
    func calendars() -> [SharedCalendar]
    func calendar(id: String) -> SharedCalendar?
    func events(calendarId: String) -> [SharedCalendarEvent]
    func events(calendarId: String, of type: EventType) -> [SharedCalendarEvent]
}

extension SharedCalendarRepository {
    func calendar(id: String) -> SharedCalendar? {
        calendars().first { $0.id == id }
    }
    
    func events(calendarId: String, of type: EventType) -> [SharedCalendarEvent] {
        events(calendarId: calendarId).filter { $0.type == type }
    }
    
    func visibleEvents(calendarId: String) -> [SharedCalendarEvent] {
        guard let calendar = calendar(id: calendarId) else { return [] }
        return events(calendarId: calendarId).filter { event in
            event.isDeleted == false && calendar.sharedEventTypes.contains(event.type)
        }
    }
}

protocol SharedCalendarManaging {
    func updateLocalDisplayName(calendarId: String, name: String?)
    func removeLocalCalendar(calendarId: String)
}
