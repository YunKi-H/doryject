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

        let appliesFirstSequence = policy.shouldApply(1)
        let appliesNewestSequence = policy.shouldApply(3)
        let appliesOlderSequence = policy.shouldApply(2)
        let reappliesLatestSequence = policy.shouldApply(3)

        #expect(appliesFirstSequence)
        #expect(appliesNewestSequence)
        #expect(appliesOlderSequence == false)
        #expect(reappliesLatestSequence == false)
        #expect(policy.latestAppliedSequence == 3)
    }
}
