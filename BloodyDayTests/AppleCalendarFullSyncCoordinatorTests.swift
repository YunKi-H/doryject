//
//  AppleCalendarFullSyncCoordinatorTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Testing
@testable import BloodyDay

struct AppleCalendarFullSyncCoordinatorTests {
    @Test
    func concurrentRequestsCoalesceIntoOnePendingRerun() async {
        let coordinator = AppleCalendarFullSyncCoordinator()

        let firstRequestStarts = await coordinator.beginOrMarkPending()
        let secondRequestStarts = await coordinator.beginOrMarkPending()
        let thirdRequestStarts = await coordinator.beginOrMarkPending()
        let firstPassNeedsRerun = await coordinator.finishPassAndShouldRunAgain()
        let secondPassNeedsRerun = await coordinator.finishPassAndShouldRunAgain()

        #expect(firstRequestStarts)
        #expect(secondRequestStarts == false)
        #expect(thirdRequestStarts == false)
        #expect(firstPassNeedsRerun)
        #expect(secondPassNeedsRerun == false)
    }

    @Test
    func newRequestCanStartAfterAllPassesFinish() async {
        let coordinator = AppleCalendarFullSyncCoordinator()

        let firstRequestStarts = await coordinator.beginOrMarkPending()
        let firstPassNeedsRerun = await coordinator.finishPassAndShouldRunAgain()
        let secondRequestStarts = await coordinator.beginOrMarkPending()

        #expect(firstRequestStarts)
        #expect(firstPassNeedsRerun == false)
        #expect(secondRequestStarts)
    }
}
