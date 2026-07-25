//
//  SharedCalendarSyncScheduler.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

@MainActor
final class SharedCalendarSyncScheduler: SharedCalendarSyncScheduling {
    private let authenticationService: AuthenticationService
    private let connectionRepository: CalendarConnectionRepository
    private let eventRepository: EventRepository
    private let eventSyncService: SharedCalendarEventSyncing
    private var syncTask: Task<Void, Never>?
    private var needsAnotherSync = false

    init(
        authenticationService: AuthenticationService,
        connectionRepository: CalendarConnectionRepository,
        eventRepository: EventRepository,
        eventSyncService: SharedCalendarEventSyncing
    ) {
        self.authenticationService = authenticationService
        self.connectionRepository = connectionRepository
        self.eventRepository = eventRepository
        self.eventSyncService = eventSyncService
    }

    func schedule() {
        guard syncTask == nil else {
            needsAnotherSync = true
            return
        }

        syncTask = Task { [weak self] in
            guard let self else { return }
            repeat {
                needsAnotherSync = false
                await syncLatestSnapshot()
            } while needsAnotherSync
            syncTask = nil
        }
    }

    private func syncLatestSnapshot() async {
        guard let user = authenticationService.currentUser else { return }
        do {
            guard let connection = try await connectionRepository.activeConnection(for: user.id),
                  connection.ownerID == user.id else {
                return
            }
            try await eventSyncService.syncOwnedEvents(
                eventRepository.allEvents(),
                connection: connection
            )
        } catch {
            #if DEBUG
            print("[SharedCalendarSync] failed: \(error)")
            #endif
        }
    }
}
