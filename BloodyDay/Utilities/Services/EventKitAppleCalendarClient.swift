//
//  EventKitAppleCalendarClient.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import EventKit
import Foundation

final class EventKitAppleCalendarClient: AppleCalendarClient {
    private let eventStore = EKEventStore()
    
    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }
    
    func createOrFetchCalendar(name: String, existingIdentifier: String?) -> String? {
        if let id = existingIdentifier, let existing = eventStore.calendar(withIdentifier: id) {
            return existing.calendarIdentifier
        }
        
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        calendar.source = eventStore.defaultCalendarForNewEvents?.source ?? preferredSource()
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar.calendarIdentifier
        } catch {
            return nil
        }
    }
    
    func removeCalendar(identifier: String) {
        guard let calendar = eventStore.calendar(withIdentifier: identifier) else { return }
        do {
            try eventStore.removeCalendar(calendar, commit: true)
        } catch {
        }
    }
    
    func syncEvents(
        events: [UserEvent],
        calendarIdentifier: String,
        title: String
    ) {
        guard let calendar = eventStore.calendar(withIdentifier: calendarIdentifier) else { return }
        let sortedDates = events.map { $0.date.startOfDay }.sorted()
        guard let first = sortedDates.first, let last = sortedDates.last else { return }
        
        let calendarRef = Calendar.current
        let endExclusive = calendarRef.date(byAdding: .day, value: 1, to: last)!
        
        let predicate = eventStore.predicateForEvents(withStart: first, end: endExclusive, calendars: [calendar])
        let existing = eventStore.events(matching: predicate).filter { $0.title == title }
        
        for event in existing {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            } catch {
            }
        }
        
        for event in events {
            let ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.calendar = calendar
            ekEvent.title = title
            ekEvent.isAllDay = true
            ekEvent.startDate = event.date.startOfDay
            ekEvent.endDate = calendarRef.date(byAdding: .day, value: 1, to: ekEvent.startDate)!
            do {
                try eventStore.save(ekEvent, span: .thisEvent, commit: false)
            } catch {
            }
        }
        
        do {
            try eventStore.commit()
        } catch {
        }
    }
    
    private func preferredSource() -> EKSource {
        if let local = eventStore.sources.first(where: { $0.sourceType == .local }) {
            return local
        }
        if let icloud = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            return icloud
        }
        return eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first!
    }
}
