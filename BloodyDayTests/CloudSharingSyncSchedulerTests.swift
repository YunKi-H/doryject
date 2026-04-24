//
//  CloudSharingSyncSchedulerTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

@MainActor
struct CloudSharingSyncSchedulerTests {
    @Test
    func scheduleSerializesRunningSyncAndRunsLatestPendingRequest() async throws {
        let cloudSharingService = TestCloudSharingService()
        await cloudSharingService.setBlockedSyncCallNumbers([1])
        let scheduler = CloudSharingSyncScheduler(cloudSharingService: cloudSharingService)
        let firstEvent = UserEvent(date: Date().startOfDay, type: .love)
        let secondEvent = UserEvent(date: Date().startOfDay, type: .pill)
        var firstSettings = UserSettings()
        firstSettings.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(period: false, pill: false, love: true)
        var secondSettings = UserSettings()
        secondSettings.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(period: false, pill: true, love: false)

        scheduler.schedule(settings: firstSettings, events: [firstEvent])
        try await waitUntil { await cloudSharingService.ownedEventSyncStartedCountValue() == 1 }
        scheduler.schedule(settings: secondSettings, events: [firstEvent, secondEvent])
        scheduler.schedule(settings: secondSettings, events: [secondEvent])
        await cloudSharingService.releaseBlockedSyncs()
        try await waitUntil { await cloudSharingService.syncSnapshotsCount() == 2 }

        #expect(await cloudSharingService.syncSnapshotsCount() == 2)
        #expect(await cloudSharingService.firstSyncSnapshot()?.eventIDs == [firstEvent.id])
        #expect(await cloudSharingService.lastSyncSnapshot()?.sharedEventTypes == secondSettings.calendarSharing.defaultSharedEventTypes)
        #expect(await cloudSharingService.lastSyncSnapshot()?.eventIDs == [secondEvent.id])
    }
}
