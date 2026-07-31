//
//  NotificationScheduleSequencePolicyTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/31/26.
//

import Testing
@testable import BloodyDay

struct NotificationScheduleSequencePolicyTests {
    @Test
    func onlyAppliesSubmissionsNewerThanTheLatestAppliedSequence() {
        var policy = NotificationScheduleSequencePolicy()

        #expect(policy.shouldApply(1))
        #expect(policy.shouldApply(3))
        #expect(policy.shouldApply(2) == false)
        #expect(policy.shouldApply(3) == false)
        #expect(policy.latestAppliedSequence == 3)
    }
}
