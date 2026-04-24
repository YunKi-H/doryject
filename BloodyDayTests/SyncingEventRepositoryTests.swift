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
        let cloudSharingSyncScheduler = TestCloudSharingSyncScheduler()
        let repository = makeRepository(
            base: baseRepository,
            settingsRepository: settingsRepository,
            cloudSharingSyncScheduler: cloudSharingSyncScheduler
        )
        let event = UserEvent(date: Date().startOfDay, type: .love)

        repository.save(event)
        try await waitUntil { await cloudSharingSyncScheduler.scheduledRequestsCount() == 1 }

        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.settings.calendarSharing.defaultSharedEventTypes == settings.calendarSharing.defaultSharedEventTypes)
        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.eventIDs == [event.id])
    }

    @Test
    func deleteTriggersCloudSharingSyncWithRemainingEvents() async throws {
        var settings = UserSettings()
        settings.calendarSharing.defaultSharedEventTypes = .all
        let deletedEvent = UserEvent(date: Date().startOfDay, type: .love)
        let remainingEvent = UserEvent(date: Date().startOfDay, type: .pill)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let baseRepository = RecordingEventRepository(events: [deletedEvent, remainingEvent])
        let cloudSharingSyncScheduler = TestCloudSharingSyncScheduler()
        let repository = makeRepository(
            base: baseRepository,
            settingsRepository: settingsRepository,
            cloudSharingSyncScheduler: cloudSharingSyncScheduler
        )

        repository.delete(id: deletedEvent.id)
        try await waitUntil { await cloudSharingSyncScheduler.scheduledRequestsCount() == 1 }

        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.eventIDs == [remainingEvent.id])
    }

    @Test
    func replaceTriggersCloudSharingSyncEvenWhenNoTypesAreSelected() async throws {
        var settings = UserSettings()
        settings.calendarSharing.defaultSharedEventTypes = .none
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let baseRepository = RecordingEventRepository()
        let cloudSharingSyncScheduler = TestCloudSharingSyncScheduler()
        let repository = makeRepository(
            base: baseRepository,
            settingsRepository: settingsRepository,
            cloudSharingSyncScheduler: cloudSharingSyncScheduler
        )

        repository.replace(type: .love, on: [Date().startOfDay])
        try await waitUntil { await cloudSharingSyncScheduler.scheduledRequestsCount() == 1 }

        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.settings.calendarSharing.defaultSharedEventTypes == SharedEventTypeSelection.none)
        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.eventIDs.count == 1)
    }

    private func makeRepository(
        base: EventRepository,
        settingsRepository: SettingsRepository,
        cloudSharingSyncScheduler: CloudSharingSyncScheduling
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
            cloudSharingSyncScheduler: cloudSharingSyncScheduler
        )
    }

}
