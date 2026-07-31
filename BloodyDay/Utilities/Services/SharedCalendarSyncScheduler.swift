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
    private let settingsRepository: SettingsRepository
    private let eventSyncService: SharedCalendarEventSyncing
    private let retryStore: SharedCalendarSyncRetryStore
    private var syncTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var needsAnotherSync = false

    init(
        authenticationService: AuthenticationService,
        connectionRepository: CalendarConnectionRepository,
        eventRepository: EventRepository,
        settingsRepository: SettingsRepository,
        eventSyncService: SharedCalendarEventSyncing,
        retryStore: SharedCalendarSyncRetryStore = .init()
    ) {
        self.authenticationService = authenticationService
        self.connectionRepository = connectionRepository
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        self.eventSyncService = eventSyncService
        self.retryStore = retryStore
    }

    func schedule() {
        retryStore.markPending()
        retryTask?.cancel()
        retryTask = nil
        startSyncIfNeeded()
    }

    private func startSyncIfNeeded() {
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
            scheduleAutomaticRetryIfNeeded()
        }
    }

    private func syncLatestSnapshot() async {
        guard let user = authenticationService.currentUser else {
            retryStore.recordFailure()
            return
        }
        do {
            guard let connection = try await connectionRepository.activeConnection(for: user.id),
                  connection.ownerID == user.id else {
                retryStore.clear()
                return
            }
            try await eventSyncService.syncOwnedEvents(
                eventRepository.allEvents(),
                pillCycles: eventRepository.pillCycles(),
                connection: connection,
                computationSettings: SharedCalendarComputationSettings(
                    settings: settingsRepository.load()
                )
            )
            retryStore.clear()
        } catch {
            retryStore.recordFailure()
            #if DEBUG
            print("[SharedCalendarSync] failed: \(error)")
            #endif
        }
    }

    private func scheduleAutomaticRetryIfNeeded(
        now: Date = Date()
    ) {
        guard let nextRetryDate = retryStore.nextRetryDate else {
            return
        }
        let delay = max(nextRetryDate.timeIntervalSince(now), 0)
        retryTask = Task { [weak self] in
            try? await Task<Never, Never>.sleep(
                for: .seconds(delay)
            )
            guard Task<Never, Never>.isCancelled == false,
                  let self,
                  self.retryStore.shouldRetry() else {
                return
            }
            self.retryTask = nil
            self.startSyncIfNeeded()
        }
    }
}
