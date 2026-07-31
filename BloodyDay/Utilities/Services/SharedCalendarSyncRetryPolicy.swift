//
//  SharedCalendarSyncRetryPolicy.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

struct SharedCalendarSyncRetryState: Codable, Equatable {
    let isPending: Bool
    let failureCount: Int
    let nextRetryAt: Date?
}

struct SharedCalendarSyncRetryPolicy {
    private let retryDelays: [TimeInterval]

    init(
        retryDelays: [TimeInterval] = [
            60,
            5 * 60,
            30 * 60,
            2 * 60 * 60
        ]
    ) {
        self.retryDelays = retryDelays
    }

    var newlyPendingState: SharedCalendarSyncRetryState {
        SharedCalendarSyncRetryState(
            isPending: true,
            failureCount: 0,
            nextRetryAt: nil
        )
    }

    func stateAfterFailure(
        _ state: SharedCalendarSyncRetryState,
        now: Date
    ) -> SharedCalendarSyncRetryState {
        let failureCount = state.failureCount + 1
        let delayIndex = failureCount - 1
        let nextRetryAt = retryDelays.indices.contains(delayIndex)
            ? now.addingTimeInterval(retryDelays[delayIndex])
            : nil
        return SharedCalendarSyncRetryState(
            isPending: true,
            failureCount: failureCount,
            nextRetryAt: nextRetryAt
        )
    }

    func shouldRetry(
        _ state: SharedCalendarSyncRetryState,
        now: Date
    ) -> Bool {
        guard state.isPending else {
            return false
        }
        guard let nextRetryAt = state.nextRetryAt else {
            return state.failureCount == 0
        }
        return nextRetryAt <= now
    }
}

struct SharedCalendarSyncRetryStore {
    private static let stateKey =
        "calendar.sharing.sync.retry-state.v1"
    private static let legacyPendingKey =
        "calendar.sharing.widget.pending-sync.v1"

    private let defaults: UserDefaults
    private let policy: SharedCalendarSyncRetryPolicy

    init(
        defaults: UserDefaults = UserDefaults(
            suiteName: CalendarSharingRuntimeStore.appGroupIdentifier
        ) ?? .standard,
        policy: SharedCalendarSyncRetryPolicy = .init()
    ) {
        self.defaults = defaults
        self.policy = policy
    }

    var state: SharedCalendarSyncRetryState? {
        if let data = defaults.data(forKey: Self.stateKey),
           let state = try? JSONDecoder().decode(
               SharedCalendarSyncRetryState.self,
               from: data
           ) {
            return state
        }
        guard defaults.bool(forKey: Self.legacyPendingKey) else {
            return nil
        }
        return policy.newlyPendingState
    }

    var nextRetryDate: Date? {
        state?.nextRetryAt
    }

    func markPending() {
        save(policy.newlyPendingState)
    }

    func recordFailure(now: Date = Date()) {
        let currentState = state ?? policy.newlyPendingState
        save(policy.stateAfterFailure(currentState, now: now))
    }

    func shouldRetry(now: Date = Date()) -> Bool {
        guard let state else { return false }
        return policy.shouldRetry(state, now: now)
    }

    func clear() {
        defaults.removeObject(forKey: Self.stateKey)
        defaults.removeObject(forKey: Self.legacyPendingKey)
    }

    private func save(_ state: SharedCalendarSyncRetryState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        defaults.set(data, forKey: Self.stateKey)
        defaults.set(state.isPending, forKey: Self.legacyPendingKey)
    }
}
