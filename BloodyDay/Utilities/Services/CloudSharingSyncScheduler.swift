//
//  CloudSharingSyncScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 4/23/26.
//

import Foundation

@MainActor
protocol CloudSharingSyncScheduling: AnyObject {
    func schedule(settings: UserSettings, events: [UserEvent])
}

@MainActor
final class CloudSharingSyncScheduler: CloudSharingSyncScheduling {
    private struct Request {
        let settings: UserSettings
        let events: [UserEvent]
    }
    
    private let cloudSharingService: CloudSharingService
    private var pendingRequest: Request?
    private var isRunning = false
    
    init(cloudSharingService: CloudSharingService) {
        self.cloudSharingService = cloudSharingService
    }
    
    func schedule(settings: UserSettings, events: [UserEvent]) {
        pendingRequest = Request(settings: settings, events: events)
        guard isRunning == false else { return }
        
        isRunning = true
        Task {
            await run()
        }
    }
    
    private func run() async {
        while let request = pendingRequest {
            pendingRequest = nil
            _ = try? await cloudSharingService.syncOwnedEventsIfNeeded(
                sharedEventTypes: request.settings.calendarSharing.defaultSharedEventTypes,
                settings: request.settings,
                events: request.events
            )
        }
        isRunning = false
    }
}
