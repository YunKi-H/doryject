//
//  SyncingEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 1/10/26.
//

import Foundation

final class SyncingEventRepository: EventRepository {
    private let base: EventRepository
    private let syncService: AppleCalendarSyncService

    init(base: EventRepository, syncService: AppleCalendarSyncService) {
        self.base = base
        self.syncService = syncService
    }

    func save(_ event: UserEvent) {
        base.save(event)
        if event.type == .period {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncUpsert(event: event) }
        }
    }

    func delete(id: UUID) {
        let event = base.allEvents().first(where: { $0.id == id })
        base.delete(id: id)
        if event?.type == .period {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncDelete(eventId: id, eventType: event?.type) }
        }
    }

    func delete(type: EventType, on: Date) {
        let target = on.startOfDay
        let events = base.events(of: type).filter { $0.date.startOfDay == target }
        base.delete(type: type, on: on)
        if type == .period {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncDelete(events: events) }
        }
    }

    func allEvents() -> [UserEvent] {
        base.allEvents()
    }

    func events(forMonth month: Date) -> [UserEvent] {
        base.events(forMonth: month)
    }

    func events(of type: EventType) -> [UserEvent] {
        base.events(of: type)
    }
}
