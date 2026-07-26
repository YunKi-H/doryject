//
//  CalendarConnectionRequestPolicy.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

enum CalendarConnectionRequestSubmissionDecision: Equatable, Sendable {
    case submit
    case incomingRequestExists
    case alreadyConnected
    case reverseRequestUnavailable
    case invalidRequest
}

enum CalendarConnectionRequestPolicy {
    static func submissionDecision(
        existingRequest: CalendarConnectionRequest?,
        requesterID: String
    ) -> CalendarConnectionRequestSubmissionDecision {
        guard let existingRequest else {
            return .submit
        }

        if existingRequest.senderID == requesterID {
            return existingRequest.status == .accepted
                ? .alreadyConnected
                : .submit
        }

        guard existingRequest.recipientID == requesterID else {
            return .invalidRequest
        }

        switch existingRequest.status {
        case .pending:
            return .incomingRequestExists
        case .accepted:
            return .alreadyConnected
        case .declined:
            return .reverseRequestUnavailable
        }
    }
}
