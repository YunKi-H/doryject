//
//  SyncingEventRepositoryTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/31/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct SyncingEventRepositoryTests {
    @Test
    func failedLocalSaveSkipsEveryExternalRefresh() {
        let base = FailingEventRepository()
        let settings = SyncingSettingsRepository()
        let notifications = NotificationRefreshRecorder()
        let widgets = WidgetRefreshRecorder()
        let sharing = SharingRefreshRecorder()
        let appleCalendar = AppleCalendarSyncService(
            settingsRepository: settings,
            eventRepository: base,
            calendarClient: NoopAppleCalendarClient(),
            syncStore: SyncingAppleCalendarStore()
        )
        let repository = SyncingEventRepository(
            base: base,
            syncService: appleCalendar,
            settingsRepository: settings,
            notificationScheduler: notifications,
            widgetReloader: widgets,
            sharedCalendarSyncScheduler: sharing
        )

        let result = repository.save(
            UserEvent(date: .now, type: .pill)
        )

        #expect(result.succeeded == false)
        #expect(settings.load().pill.pillEnabled == false)
        #expect(notifications.applyCount == 0)
        #expect(widgets.reloadCount == 0)
        #expect(sharing.scheduleCount == 0)
    }
}

private struct LocalSaveFailure: Error {}

private final class FailingEventRepository: EventRepository {
    func save(_ event: UserEvent) -> EventMutationResult {
        .failed(LocalSaveFailure())
    }

    func delete(id: UUID) -> EventMutationResult {
        .failed(LocalSaveFailure())
    }

    func delete(type: EventType, on: Date) -> EventMutationResult {
        .failed(LocalSaveFailure())
    }

    func replace(type: EventType, on dates: Set<Date>) -> EventMutationResult {
        .failed(LocalSaveFailure())
    }

    func allEvents() -> [UserEvent] { [] }
    func events(forMonth month: Date) -> [UserEvent] { [] }
    func events(of type: EventType) -> [UserEvent] { [] }
}

private final class SyncingSettingsRepository: SettingsRepository {
    private var settings = UserSettings()

    func load() -> UserSettings { settings }

    func save(_ settings: UserSettings) {
        self.settings = settings
    }
}

private final class NotificationRefreshRecorder: NotificationScheduler {
    private(set) var applyCount = 0

    func apply(settings: UserSettings, eventRepository: EventRepository) {
        applyCount += 1
    }
}

private final class WidgetRefreshRecorder: WidgetReloading {
    private(set) var reloadCount = 0

    func reloadAll() {
        reloadCount += 1
    }
}

private final class SharingRefreshRecorder: SharedCalendarSyncScheduling {
    private(set) var scheduleCount = 0

    func schedule() {
        scheduleCount += 1
    }
}

private final class SyncingAppleCalendarStore: AppleCalendarSyncStore {
    func record(for eventId: UUID) -> AppleCalendarSyncRecord? { nil }
    func records() -> [AppleCalendarSyncRecord] { [] }
    func upsert(_ record: AppleCalendarSyncRecord) {}
    func remove(for eventId: UUID) {}
    func removeAll() {}
}
