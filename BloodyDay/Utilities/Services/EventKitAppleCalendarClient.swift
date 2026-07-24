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
    private var systemCalendar: Calendar { .autoupdatingCurrent }
    
    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }
    
    func createOrFetchCalendar(name: String, existingIdentifier: String?) -> String? {
        if let id = existingIdentifier, let existing = eventStore.calendar(withIdentifier: id) {
            if existing.title != name {
                existing.title = name
                do {
                    try eventStore.saveCalendar(existing, commit: true)
                } catch {
                    return existing.calendarIdentifier
                }
            }
            return existing.calendarIdentifier
        }
        
        let eventCalendar = EKCalendar(for: .event, eventStore: eventStore)
        eventCalendar.title = name
        eventCalendar.source = eventStore.defaultCalendarForNewEvents?.source ?? preferredSource()
        
        do {
            try eventStore.saveCalendar(eventCalendar, commit: true)
            return eventCalendar.calendarIdentifier
        } catch {
            return nil
        }
    }
    
    func removeCalendar(identifier: String) {
        guard let eventCalendar = eventStore.calendar(withIdentifier: identifier) else { return }
        do {
            try eventStore.removeCalendar(eventCalendar, commit: true)
        } catch {
        }
    }
    
    func upsertEvent(
        event: UserEvent,
        calendarIdentifier: String,
        title: String,
        existingEventIdentifier: String?,
        dateRange: DateInterval?
    ) -> String? {
        guard let eventCalendar = eventStore.calendar(withIdentifier: calendarIdentifier) else { return nil }
        let ekEvent = existingEventIdentifier
            .flatMap { eventStore.event(withIdentifier: $0) }
            ?? matchingEvent(for: event, in: eventCalendar, dateRange: dateRange)
            ?? EKEvent(eventStore: eventStore)
        ekEvent.calendar = eventCalendar
        ekEvent.title = title
        ekEvent.isAllDay = true
        if let range = dateRange {
            ekEvent.startDate = systemCalendar.startOfDay(for: range.start)
            ekEvent.endDate = range.end
        } else {
            ekEvent.startDate = systemCalendar.startOfDay(for: event.date)
            ekEvent.endDate = event.date.endOfDay(in: systemCalendar)
        }
        ekEvent.url = AppDeepLink.calendarURL(for: event.date)
        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
            return ekEvent.eventIdentifier
        } catch {
            return nil
        }
    }

    private func matchingEvent(
        for event: UserEvent,
        in eventCalendar: EKCalendar,
        dateRange: DateInterval?
    ) -> EKEvent? {
        let rangeStart = dateRange.map {
            systemCalendar.startOfDay(for: $0.start)
        } ?? systemCalendar.startOfDay(for: event.date)
        let rangeEnd = dateRange?.end ?? event.date.endOfDay(in: systemCalendar)
        let predicate = eventStore.predicateForEvents(
            withStart: rangeStart,
            end: rangeEnd,
            calendars: [eventCalendar]
        )
        let expectedURL = AppDeepLink.calendarURL(for: event.date)

        return eventStore.events(matching: predicate).first { existing in
            existing.isAllDay
                && systemCalendar.startOfDay(for: existing.startDate) == rangeStart
                && existing.url == expectedURL
        }
    }
    
    func deleteEvent(identifier: String) {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
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
