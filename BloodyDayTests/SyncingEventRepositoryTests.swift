//
//  SyncingEventRepositoryTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct SyncingEventRepositoryTests {
    @Test
    func saveTriggersCloudSharingSyncWithUpdatedEvents() async throws {
        var settings = UserSettings()
        settings.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(period: true, pill: false, love: true)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let baseRepository = RecordingEventRepository()
        let cloudSharingService = TestCloudSharingService()
        let repository = makeRepository(
            base: baseRepository,
            settingsRepository: settingsRepository,
            cloudSharingService: cloudSharingService
        )
        let event = UserEvent(date: Date().startOfDay, type: .love)

        repository.save(event)
        try await waitUntil { cloudSharingService.ownedEventSyncCallCount == 1 }

        #expect(cloudSharingService.lastSyncedSharedEventTypes == settings.calendarSharing.defaultSharedEventTypes)
        #expect(cloudSharingService.lastSyncedEvents.map(\.id) == [event.id])
    }

    @Test
    func deleteTriggersCloudSharingSyncWithRemainingEvents() async throws {
        var settings = UserSettings()
        settings.calendarSharing.defaultSharedEventTypes = .all
        let deletedEvent = UserEvent(date: Date().startOfDay, type: .love)
        let remainingEvent = UserEvent(date: Date().startOfDay, type: .pill)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let baseRepository = RecordingEventRepository(events: [deletedEvent, remainingEvent])
        let cloudSharingService = TestCloudSharingService()
        let repository = makeRepository(
            base: baseRepository,
            settingsRepository: settingsRepository,
            cloudSharingService: cloudSharingService
        )

        repository.delete(id: deletedEvent.id)
        try await waitUntil { cloudSharingService.ownedEventSyncCallCount == 1 }

        #expect(cloudSharingService.lastSyncedEvents.map(\.id) == [remainingEvent.id])
    }

    @Test
    func replaceTriggersCloudSharingSyncEvenWhenNoTypesAreSelected() async throws {
        var settings = UserSettings()
        settings.calendarSharing.defaultSharedEventTypes = .none
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let baseRepository = RecordingEventRepository()
        let cloudSharingService = TestCloudSharingService()
        let repository = makeRepository(
            base: baseRepository,
            settingsRepository: settingsRepository,
            cloudSharingService: cloudSharingService
        )

        repository.replace(type: .love, on: [Date().startOfDay])
        try await waitUntil { cloudSharingService.ownedEventSyncCallCount == 1 }

        #expect(cloudSharingService.lastSyncedSharedEventTypes == SharedEventTypeSelection.none)
        #expect(cloudSharingService.lastSyncedEvents.count == 1)
    }

    private func makeRepository(
        base: EventRepository,
        settingsRepository: SettingsRepository,
        cloudSharingService: CloudSharingService
    ) -> SyncingEventRepository {
        let appleCalendarService = AppleCalendarSyncService(
            settingsRepository: settingsRepository,
            eventRepository: base,
            calendarClient: NoopAppleCalendarClient(),
            syncStore: InMemoryAppleCalendarSyncStore()
        )
        return SyncingEventRepository(
            base: base,
            syncService: appleCalendarService,
            settingsRepository: settingsRepository,
            cloudSharingService: cloudSharingService
        )
    }

}
