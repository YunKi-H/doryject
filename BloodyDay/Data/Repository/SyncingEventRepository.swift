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
    private let settingsRepository: SettingsRepository?
    private let notificationScheduler: NotificationScheduler?
    private let widgetReloader: WidgetReloading?
    private var calendar: Calendar { .autoupdatingCurrent }
    
    init(
        base: EventRepository,
        syncService: AppleCalendarSyncService,
        settingsRepository: SettingsRepository? = nil,
        notificationScheduler: NotificationScheduler? = nil,
        widgetReloader: WidgetReloading? = nil
    ) {
        self.base = base
        self.syncService = syncService
        self.settingsRepository = settingsRepository
        self.notificationScheduler = notificationScheduler
        self.widgetReloader = widgetReloader
    }
    
    func save(_ event: UserEvent) {
        enablePillIfNeeded(for: event)
        base.save(event)
        if AppleCalendarEventSyncPolicy.requiresFullSync(for: event.type) {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncUpsert(event: event) }
        }
        refreshNotifications()
        refreshWidgets()
    }
    
    func delete(id: UUID) {
        let event = base.allEvents().first(where: { $0.id == id })
        base.delete(id: id)
        if let type = event?.type,
           AppleCalendarEventSyncPolicy.requiresFullSync(for: type) {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncDelete(eventId: id, eventType: event?.type) }
        }
        refreshNotifications()
        refreshWidgets()
    }
    
    func delete(type: EventType, on: Date) {
        let target = calendar.startOfDay(for: on)
        let events = base.events(of: type).filter {
            calendar.startOfDay(for: $0.date) == target
        }
        base.delete(type: type, on: on)
        if AppleCalendarEventSyncPolicy.requiresFullSync(for: type) {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncDelete(events: events) }
        }
        refreshNotifications()
        refreshWidgets()
    }
    
    func replace(type: EventType, on dates: Set<Date>) {
        if type == .pill, !dates.isEmpty {
            enablePillIfNeeded()
        }
        base.replace(type: type, on: dates)
        Task { await syncService.syncAll() }
        refreshNotifications()
        refreshWidgets()
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

    func pillCycles() -> [PillCycleInfo] {
        base.pillCycles()
    }
    
    private func refreshNotifications() {
        guard let scheduler = notificationScheduler,
              let settingsRepository = settingsRepository else { return }
        let settings = settingsRepository.load()
        scheduler.apply(settings: settings, eventRepository: base)
    }
    
    private func refreshWidgets() {
        widgetReloader?.reloadAll()
    }

    private func enablePillIfNeeded(for event: UserEvent) {
        guard event.type == .pill,
              let settingsRepository else { return }
        var settings = settingsRepository.load()
        guard settings.pill.pillEnabled == false else { return }
        settings.pill.pillEnabled = true
        settingsRepository.save(settings)
    }
    
    private func enablePillIfNeeded() {
        guard let settingsRepository else { return }
        var settings = settingsRepository.load()
        guard settings.pill.pillEnabled == false else { return }
        settings.pill.pillEnabled = true
        settingsRepository.save(settings)
    }
}

enum AppleCalendarEventSyncPolicy {
    static func requiresFullSync(for type: EventType) -> Bool {
        type == .period || type == .pill
    }
}
