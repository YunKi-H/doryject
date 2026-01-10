//
//  AppleCalendarSyncService.swift
//  BloodyDay
//
//  Created by Yunki on 1/10/26.
//

import Foundation

final class AppleCalendarSyncService {
    private let settingsRepository: SettingsRepository
    private let eventRepository: EventRepository
    private let calendarClient: AppleCalendarClient
    private let syncStore: AppleCalendarSyncStore
    private let supportedTypes: [EventType] = [.period, .pill, .love]

    init(
        settingsRepository: SettingsRepository,
        eventRepository: EventRepository,
        calendarClient: AppleCalendarClient,
        syncStore: AppleCalendarSyncStore
    ) {
        self.settingsRepository = settingsRepository
        self.eventRepository = eventRepository
        self.calendarClient = calendarClient
        self.syncStore = syncStore
    }

    func syncAll() async {
        var settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard await calendarClient.requestAccess() else { return }

        for type in supportedTypes {
            if settings.appleCalendar.eventSyncEnabled[type] == true {
                if let calendarId = await ensureCalendar(for: type, settings: &settings) {
                    let events = eventRepository.events(of: type)
                    for event in events {
                        await upsert(event: event, type: type, calendarIdentifier: calendarId)
                    }
                }
            } else {
                removeEvents(for: type)
            }
        }

        removeOrphanedRecords(validEvents: eventRepository.allEvents())
    }

    func syncUpsert(event: UserEvent) async {
        let settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard supportedTypes.contains(event.type) else { return }
        guard settings.appleCalendar.eventSyncEnabled[event.type] == true else { return }
        guard await calendarClient.requestAccess() else { return }

        var mutableSettings = settings
        guard let calendarId = await ensureCalendar(for: event.type, settings: &mutableSettings) else { return }
        await upsert(event: event, type: event.type, calendarIdentifier: calendarId)
    }

    func syncDelete(eventId: UUID, eventType: EventType?) async {
        let settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard await calendarClient.requestAccess() else { return }

        if let record = syncStore.record(for: eventId) {
            calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
            syncStore.remove(for: eventId)
        } else if let type = eventType, supportedTypes.contains(type) {
            // No record found, nothing to delete.
        }
    }

    func syncDelete(events: [UserEvent]) async {
        guard !events.isEmpty else { return }
        let settings = settingsRepository.load()
        guard settings.appleCalendar.isEnabled else { return }
        guard await calendarClient.requestAccess() else { return }

        for event in events {
            if let record = syncStore.record(for: event.id) {
                calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
                syncStore.remove(for: event.id)
            }
        }
    }

    private func ensureCalendar(
        for type: EventType,
        settings: inout UserSettings
    ) async -> String? {
        let name = settings.appleCalendar.calendarNames[type]
            ?? AppleCalendarSettings.defaultCalendarNames[type, default: "BloodyDay"]
        let existing = settings.appleCalendar.calendarIdentifiers[type]
        let identifier = calendarClient.createOrFetchCalendar(name: name, existingIdentifier: existing)
        if let identifier {
            settings.appleCalendar.calendarIdentifiers[type] = identifier
            settingsRepository.save(settings)
        }
        return identifier
    }

    private func upsert(
        event: UserEvent,
        type: EventType,
        calendarIdentifier: String
    ) async {
        let existing = syncStore.record(for: event.id)?.ekEventIdentifier
        let title = defaultTitle(for: type)
        if let ekId = calendarClient.upsertEvent(
            event: event,
            calendarIdentifier: calendarIdentifier,
            title: title,
            existingEventIdentifier: existing
        ) {
            let record = AppleCalendarSyncRecord(
                userEventId: event.id,
                eventType: type,
                calendarIdentifier: calendarIdentifier,
                ekEventIdentifier: ekId,
                lastSyncedAt: Date()
            )
            syncStore.upsert(record)
        }
    }

    private func removeEvents(for type: EventType) {
        let records = syncStore.records().filter { $0.eventType == type }
        for record in records {
            calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
            syncStore.remove(for: record.userEventId)
        }
    }

    private func removeOrphanedRecords(validEvents: [UserEvent]) {
        let validIds = Set(validEvents.map(\.id))
        for record in syncStore.records() where !validIds.contains(record.userEventId) {
            calendarClient.deleteEvent(identifier: record.ekEventIdentifier)
            syncStore.remove(for: record.userEventId)
        }
    }

    private func defaultTitle(for type: EventType) -> String {
        switch type {
        case .period:
            return "생리"
        case .pill:
            return "피임약 복용"
        case .love:
            return "사랑한 날"
        default:
            return "BloodyDay"
        }
    }
}
