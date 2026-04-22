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
    private let cloudSharingService: CloudSharingService?

    init(
        base: EventRepository,
        syncService: AppleCalendarSyncService,
        settingsRepository: SettingsRepository? = nil,
        notificationScheduler: NotificationScheduler? = nil,
        widgetReloader: WidgetReloading? = nil,
        cloudSharingService: CloudSharingService? = nil
    ) {
        self.base = base
        self.syncService = syncService
        self.settingsRepository = settingsRepository
        self.notificationScheduler = notificationScheduler
        self.widgetReloader = widgetReloader
        self.cloudSharingService = cloudSharingService
    }

    func save(_ event: UserEvent) {
        enablePillIfNeeded(for: event)
        base.save(event)
        if event.type == .period {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncUpsert(event: event) }
        }
        refreshNotifications()
        refreshWidgets()
        syncCloudSharing()
    }

    func delete(id: UUID) {
        let event = base.allEvents().first(where: { $0.id == id })
        base.delete(id: id)
        if event?.type == .period {
            Task { await syncService.syncAll() }
        } else {
            Task { await syncService.syncDelete(eventId: id, eventType: event?.type) }
        }
        refreshNotifications()
        refreshWidgets()
        syncCloudSharing()
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
        refreshNotifications()
        refreshWidgets()
        syncCloudSharing()
    }

    func replace(type: EventType, on dates: Set<Date>) {
        if type == .pill, !dates.isEmpty {
            enablePillIfNeeded()
        }
        base.replace(type: type, on: dates)
        Task { await syncService.syncAll() }
        refreshNotifications()
        refreshWidgets()
        syncCloudSharing()
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

    private func refreshNotifications() {
        guard let scheduler = notificationScheduler,
              let settingsRepository = settingsRepository else { return }
        let settings = settingsRepository.load()
        scheduler.apply(settings: settings, eventRepository: base)
    }

    private func refreshWidgets() {
        widgetReloader?.reloadAll()
    }

    private func syncCloudSharing() {
        guard let settingsRepository,
              let cloudSharingService else { return }
        let settings = settingsRepository.load()
        let sharedEventTypes = settings.calendarSharing.defaultSharedEventTypes
        let events = base.allEvents()
        Task {
            _ = try? await cloudSharingService.syncOwnedEventsIfNeeded(
                sharedEventTypes: sharedEventTypes,
                settings: settings,
                events: events
            )
        }
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
