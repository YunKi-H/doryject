//
//  CloudSharingSyncScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 4/23/26.
//

import Foundation

protocol CloudSharingSyncScheduling: AnyObject {
    func schedule(settings: UserSettings, events: [UserEvent])
}

final class CloudSharingSyncScheduler: CloudSharingSyncScheduling {
    private struct Request {
        let settings: UserSettings
        let events: [UserEvent]
    }

    private let cloudSharingService: CloudSharingService
    private let stateQueue = DispatchQueue(label: "CloudSharingSyncScheduler.state")
    private var pendingRequest: Request?
    private var isRunning = false

    init(cloudSharingService: CloudSharingService) {
        self.cloudSharingService = cloudSharingService
    }

    func schedule(settings: UserSettings, events: [UserEvent]) {
        let shouldStart = stateQueue.sync { () -> Bool in
            pendingRequest = Request(settings: settings, events: events)
            guard isRunning == false else { return false }
            isRunning = true
            return true
        }

        guard shouldStart else { return }

        Task.detached { [weak self] in
            await self?.run()
        }
    }

    private func run() async {
        while let request = nextRequest() {
            _ = try? await cloudSharingService.syncOwnedEventsIfNeeded(
                sharedEventTypes: request.settings.calendarSharing.defaultSharedEventTypes,
                settings: request.settings,
                events: request.events
            )
        }
    }

    private func nextRequest() -> Request? {
        stateQueue.sync {
            guard let request = pendingRequest else {
                isRunning = false
                return nil
            }
            pendingRequest = nil
            return request
        }
    }
}
