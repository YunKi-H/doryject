//
//  LocalSharedCalendarRepository.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

final class LocalSharedCalendarRepository: SharedCalendarRepository, SharedCalendarManaging {
    private var storedCalendars: [SharedCalendar]
    private var storedEventsByCalendarId: [String: [SharedCalendarEvent]]
    
    init(
        calendars: [SharedCalendar] = [],
        eventsByCalendarId: [String: [SharedCalendarEvent]] = [:]
    ) {
        self.storedCalendars = calendars
        self.storedEventsByCalendarId = eventsByCalendarId
    }
    
    func calendars() -> [SharedCalendar] {
        storedCalendars
    }
    
    func calendar(id: String) -> SharedCalendar? {
        storedCalendars.first { $0.id == id }
    }
    
    func events(calendarId: String) -> [SharedCalendarEvent] {
        storedEventsByCalendarId[calendarId, default: []]
    }
    
    func updateLocalDisplayName(calendarId: String, name: String?) {
        guard let index = storedCalendars.firstIndex(where: { $0.id == calendarId }) else { return }
        storedCalendars[index].localDisplayName = name
    }
    
    func removeLocalCalendar(calendarId: String) {
        storedCalendars.removeAll { $0.id == calendarId }
        storedEventsByCalendarId.removeValue(forKey: calendarId)
    }
    
    func replaceCalendars(_ calendars: [SharedCalendar]) {
        storedCalendars = calendars
        let validIds = Set(calendars.map(\.id))
        storedEventsByCalendarId = storedEventsByCalendarId.filter { validIds.contains($0.key) }
    }
    
    func replaceEvents(calendarId: String, events: [SharedCalendarEvent]) {
        storedEventsByCalendarId[calendarId] = events
    }
}

final class MockSharedCalendarRepository: SharedCalendarRepository, SharedCalendarManaging {
    private let local: LocalSharedCalendarRepository
    
    init(
        calendars: [SharedCalendar] = MockSharedCalendarRepository.sampleCalendars,
        eventsByCalendarId: [String: [SharedCalendarEvent]] = MockSharedCalendarRepository.sampleEventsByCalendarId
    ) {
        self.local = LocalSharedCalendarRepository(
            calendars: calendars,
            eventsByCalendarId: eventsByCalendarId
        )
    }
    
    func calendars() -> [SharedCalendar] {
        local.calendars()
    }
    
    func calendar(id: String) -> SharedCalendar? {
        local.calendar(id: id)
    }
    
    func events(calendarId: String) -> [SharedCalendarEvent] {
        local.events(calendarId: calendarId)
    }
    
    func updateLocalDisplayName(calendarId: String, name: String?) {
        local.updateLocalDisplayName(calendarId: calendarId, name: name)
    }
    
    func removeLocalCalendar(calendarId: String) {
        local.removeLocalCalendar(calendarId: calendarId)
    }
    
    private static let sampleCalendarId = "mock-shared-calendar"
    
    private static var sampleCalendars: [SharedCalendar] {
        [
            SharedCalendar(
                id: sampleCalendarId,
                ownerDisplayName: "민지",
                remoteTitle: "민지의 B-Day",
                localDisplayName: "민지",
                sharedEventTypes: SharedEventTypeSelection(period: true, pill: true, love: true),
                permission: .readOnly,
                acceptedAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private static var sampleEventsByCalendarId: [String: [SharedCalendarEvent]] {
        let today = Date().startOfDay
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)?.startOfDay else {
            return [:]
        }
        
        return [
            sampleCalendarId: [
                SharedCalendarEvent(
                    id: "mock-period-1",
                    calendarId: sampleCalendarId,
                    sourceEventId: "source-period-1",
                    type: .period,
                    date: today,
                    updatedAt: Date()
                ),
                SharedCalendarEvent(
                    id: "mock-pill-1",
                    calendarId: sampleCalendarId,
                    sourceEventId: "source-pill-1",
                    type: .pill,
                    date: today,
                    updatedAt: Date()
                ),
                SharedCalendarEvent(
                    id: "mock-love-1",
                    calendarId: sampleCalendarId,
                    sourceEventId: "source-love-1",
                    type: .love,
                    date: yesterday,
                    updatedAt: Date()
                )
            ]
        ]
    }
}
