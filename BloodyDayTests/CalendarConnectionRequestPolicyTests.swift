//
//  CalendarConnectionRequestPolicyTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarConnectionRequestPolicyTests {
    @Test
    func allowsNewAndSameSenderRetryRequests() {
        #expect(decision(existingRequest: nil) == .submit)
        #expect(
            decision(
                existingRequest: request(
                    senderID: "requester",
                    recipientID: "partner",
                    status: .pending
                )
            ) == .submit
        )
        #expect(
            decision(
                existingRequest: request(
                    senderID: "requester",
                    recipientID: "partner",
                    status: .declined
                )
            ) == .submit
        )
    }

    @Test
    func rejectsAlreadyAcceptedRequest() {
        #expect(
            decision(
                existingRequest: request(
                    senderID: "requester",
                    recipientID: "partner",
                    status: .accepted
                )
            ) == .alreadyConnected
        )
        #expect(
            decision(
                existingRequest: request(
                    senderID: "partner",
                    recipientID: "requester",
                    status: .accepted
                )
            ) == .alreadyConnected
        )
    }

    @Test
    func directsRequesterToExistingIncomingRequest() {
        #expect(
            decision(
                existingRequest: request(
                    senderID: "partner",
                    recipientID: "requester",
                    status: .pending
                )
            ) == .incomingRequestExists
        )
    }

    @Test
    func rejectsReverseRequestAfterIncomingRequestWasDeclined() {
        #expect(
            decision(
                existingRequest: request(
                    senderID: "partner",
                    recipientID: "requester",
                    status: .declined
                )
            ) == .reverseRequestUnavailable
        )
    }

    @Test
    func rejectsRequestUnrelatedToRequester() {
        #expect(
            decision(
                existingRequest: request(
                    senderID: "first",
                    recipientID: "second",
                    status: .pending
                )
            ) == .invalidRequest
        )
    }

    private func decision(
        existingRequest: CalendarConnectionRequest?
    ) -> CalendarConnectionRequestSubmissionDecision {
        CalendarConnectionRequestPolicy.submissionDecision(
            existingRequest: existingRequest,
            requesterID: "requester"
        )
    }

    private func request(
        senderID: String,
        recipientID: String,
        status: CalendarConnectionRequestStatus
    ) -> CalendarConnectionRequest {
        CalendarConnectionRequest(
            id: "request",
            senderID: senderID,
            senderDisplayName: "Sender",
            recipientID: recipientID,
            status: status,
            createdAt: .distantPast
        )
    }
}
