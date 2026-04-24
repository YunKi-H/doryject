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
        cloudSharingService.blockedSyncCallNumbers = [1]
        let scheduler = CloudSharingSyncScheduler(cloudSharingService: cloudSharingService)
        let firstEvent = UserEvent(date: Date().startOfDay, type: .love)
        let secondEvent = UserEvent(date: Date().startOfDay, type: .pill)
        var firstSettings = UserSettings()
        firstSettings.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(period: false, pill: false, love: true)
        var secondSettings = UserSettings()
        secondSettings.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(period: false, pill: true, love: false)
        
        await scheduler.schedule(settings: firstSettings, events: [firstEvent])
        try await waitUntil { cloudSharingService.ownedEventSyncStartedCount == 1 }
        await scheduler.schedule(settings: secondSettings, events: [firstEvent, secondEvent])
        await scheduler.schedule(settings: secondSettings, events: [secondEvent])
        cloudSharingService.releaseBlockedSyncs()
        try await waitUntil { cloudSharingService.syncSnapshots.count == 2 }
        
        #expect(cloudSharingService.syncSnapshots.count == 2)
        #expect(cloudSharingService.syncSnapshots.first?.eventIDs == [firstEvent.id])
        #expect(cloudSharingService.syncSnapshots.last?.sharedEventTypes == secondSettings.calendarSharing.defaultSharedEventTypes)
        #expect(cloudSharingService.syncSnapshots.last?.eventIDs == [secondEvent.id])
    }
}
