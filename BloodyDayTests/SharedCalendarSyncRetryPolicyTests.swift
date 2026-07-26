//
//  SharedCalendarSyncRetryPolicyTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct SharedCalendarSyncRetryPolicyTests {
    @Test
    func failureUsesConfiguredBackoffAndStopsAutomaticRetry() {
        let policy = SharedCalendarSyncRetryPolicy(
            retryDelays: [10, 20]
        )
        let now = Date(timeIntervalSince1970: 1_000)

        let firstFailure = policy.stateAfterFailure(
            policy.newlyPendingState,
            now: now
        )
        let secondFailure = policy.stateAfterFailure(
            firstFailure,
            now: now
        )
        let finalFailure = policy.stateAfterFailure(
            secondFailure,
            now: now
        )

        #expect(firstFailure.failureCount == 1)
        #expect(firstFailure.nextRetryAt == now.addingTimeInterval(10))
        #expect(secondFailure.failureCount == 2)
        #expect(secondFailure.nextRetryAt == now.addingTimeInterval(20))
        #expect(finalFailure.failureCount == 3)
        #expect(finalFailure.nextRetryAt == nil)
        #expect(finalFailure.isPending)
    }

    @Test
    func retryBecomesEligibleAtScheduledDate() {
        let policy = SharedCalendarSyncRetryPolicy(
            retryDelays: [10]
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let state = policy.stateAfterFailure(
            policy.newlyPendingState,
            now: now
        )

        #expect(
            policy.shouldRetry(
                state,
                now: now.addingTimeInterval(9)
            ) == false
        )
        #expect(
            policy.shouldRetry(
                state,
                now: now.addingTimeInterval(10)
            )
        )
    }

    @Test
    func newlyPendingWorkRetriesImmediatelyButExhaustedWorkDoesNot() {
        let policy = SharedCalendarSyncRetryPolicy(retryDelays: [])
        let now = Date(timeIntervalSince1970: 1_000)
        let exhaustedState = policy.stateAfterFailure(
            policy.newlyPendingState,
            now: now
        )

        #expect(policy.shouldRetry(policy.newlyPendingState, now: now))
        #expect(policy.shouldRetry(exhaustedState, now: now) == false)
    }

    @Test
    func storePersistsFailureAndNewChangeResetsBackoff() throws {
        let suiteName =
            "SharedCalendarSyncRetryPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = SharedCalendarSyncRetryStore(
            defaults: defaults,
            policy: SharedCalendarSyncRetryPolicy(retryDelays: [10])
        )
        let now = Date(timeIntervalSince1970: 1_000)

        store.markPending()
        store.recordFailure(now: now)

        #expect(store.state?.failureCount == 1)
        #expect(
            store.nextRetryDate == now.addingTimeInterval(10)
        )

        store.markPending()

        #expect(store.state?.failureCount == 0)
        #expect(store.nextRetryDate == nil)
    }

    @Test
    func legacyPendingFlagMigratesAsImmediatelyRetryable() throws {
        let suiteName =
            "SharedCalendarSyncRetryPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(
            true,
            forKey: "calendar.sharing.widget.pending-sync.v1"
        )
        let store = SharedCalendarSyncRetryStore(defaults: defaults)

        #expect(store.state?.failureCount == 0)
        #expect(store.shouldRetry())
    }
}
