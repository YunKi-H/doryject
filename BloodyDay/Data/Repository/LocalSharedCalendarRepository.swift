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
                predictionSettings: SharedCalendarPredictionSettings(
                    autoCyclePredictionEnabled: true,
                    averageCycleDays: 28,
                    averagePeriodDays: 5,
                    pillEnabled: true,
                    pillAutoRecordEnabled: true,
                    pillCount: 21,
                    pillBreakDuration: 7
                ),
                permission: .readOnly,
                acceptedAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private static var sampleEventsByCalendarId: [String: [SharedCalendarEvent]] {
        let today = Date().startOfDay
        guard
            let loveDate = Calendar.current.date(byAdding: .day, value: -1, to: today)?.startOfDay,
            let recentPeriodStart = Calendar.current.date(byAdding: .day, value: -26, to: today)?.startOfDay,
            let previousPeriodStart = Calendar.current.date(byAdding: .day, value: -54, to: today)?.startOfDay,
            let pillStart = Calendar.current.date(byAdding: .day, value: -15, to: today)?.startOfDay
        else {
            return [:]
        }
        
        let recentPeriodDates = (0..<5).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: recentPeriodStart)?.startOfDay
        }
        let previousPeriodDates = (0..<5).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: previousPeriodStart)?.startOfDay
        }
        let pillDates = (0..<16).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: pillStart)?.startOfDay
        }
        
        let periodEvents = (previousPeriodDates + recentPeriodDates).enumerated().map { index, date in
            SharedCalendarEvent(
                id: "mock-period-\(index)",
                calendarId: sampleCalendarId,
                sourceEventId: "source-period-\(index)",
                type: .period,
                date: date,
                updatedAt: Date()
            )
        }
        let pillEvents = pillDates.enumerated().map { index, date in
            SharedCalendarEvent(
                id: "mock-pill-\(index)",
                calendarId: sampleCalendarId,
                sourceEventId: "source-pill-\(index)",
                type: .pill,
                date: date,
                updatedAt: Date()
            )
        }
        let loveEvents = [
            SharedCalendarEvent(
                id: "mock-love-0",
                calendarId: sampleCalendarId,
                sourceEventId: "source-love-0",
                type: .love,
                date: loveDate,
                updatedAt: Date()
            )
        ]
        
        return [
            sampleCalendarId: periodEvents + pillEvents + loveEvents
        ]
    }
}
