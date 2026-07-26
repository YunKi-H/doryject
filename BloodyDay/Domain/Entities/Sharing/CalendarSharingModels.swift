//
//  CalendarSharingModels.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

struct CalendarSharingProfile: Equatable, Sendable {
    let userID: String
    let displayName: String
    let connectionCode: String
}

enum CalendarConnectionRequestStatus: String, Sendable {
    case pending
    case accepted
    case declined
}

struct CalendarConnectionRequest: Identifiable, Equatable, Sendable {
    let id: String
    let senderID: String
    let senderDisplayName: String
    let recipientID: String
    let status: CalendarConnectionRequestStatus
    let createdAt: Date
}

struct CalendarConnection: Identifiable, Equatable, Sendable {
    let id: String
    let ownerID: String
    let ownerDisplayName: String
    let viewerID: String
    let viewerDisplayName: String
    let sharedEventTypes: SharedEventTypeSelection
    let createdAt: Date
    let computationSettings: SharedCalendarComputationSettings?

    init(
        id: String,
        ownerID: String,
        ownerDisplayName: String,
        viewerID: String,
        viewerDisplayName: String,
        sharedEventTypes: SharedEventTypeSelection,
        createdAt: Date,
        computationSettings: SharedCalendarComputationSettings? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.ownerDisplayName = ownerDisplayName
        self.viewerID = viewerID
        self.viewerDisplayName = viewerDisplayName
        self.sharedEventTypes = sharedEventTypes
        self.createdAt = createdAt
        self.computationSettings = computationSettings
    }

    func role(for userID: String) -> CalendarConnectionRole? {
        if ownerID == userID {
            return .owner
        }
        if viewerID == userID {
            return .viewer
        }
        return nil
    }

    func partnerDisplayName(for userID: String) -> String {
        ownerID == userID ? viewerDisplayName : ownerDisplayName
    }
}

struct SharedEventTypeSelection: Equatable, Sendable {
    var period = true
    var pill = true
    var love = true

    func includes(_ type: EventType) -> Bool {
        switch type {
        case .period:
            return period
        case .pill:
            return pill
        case .love:
            return love
        case .ovulation, .fertile, .delayed:
            return false
        }
    }
}

enum CalendarConnectionRole: Sendable {
    case owner
    case viewer
}
