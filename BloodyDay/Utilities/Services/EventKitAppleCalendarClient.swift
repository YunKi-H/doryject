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
    
    func upsertEvent(
        event: UserEvent,
        calendarIdentifier: String,
        title: String,
        existingEventIdentifier: String?,
        dateRange: DateInterval?
    ) -> String? {
        guard let calendar = eventStore.calendar(withIdentifier: calendarIdentifier) else { return nil }
        let ekEvent = existingEventIdentifier.flatMap { eventStore.event(withIdentifier: $0) } ?? EKEvent(eventStore: eventStore)
        ekEvent.calendar = calendar
        ekEvent.title = title
        ekEvent.isAllDay = true
        if let range = dateRange {
            ekEvent.startDate = range.start.startOfDay
            ekEvent.endDate = range.end
        } else {
            ekEvent.startDate = event.date.startOfDay
            ekEvent.endDate = event.date.endOfDay
        }
        ekEvent.url = URL(string: "bloodyday://event/\(event.id.uuidString)")
        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
            return ekEvent.eventIdentifier
        } catch {
            return nil
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
