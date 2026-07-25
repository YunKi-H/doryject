//
//  FirestoreCalendarSharingMapper.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

enum FirestoreCalendarSharingMapper {
    enum Collection {
        static let users = "users"
        static let connectionCodes = "connectionCodes"
        static let requests = "connectionRequests"
        static let connections = "connections"
        static let memberships = "connectionMemberships"
    }

    static func profile(
        userID: String,
        data: [String: Any]
    ) -> CalendarSharingProfile? {
        guard let displayName = data["displayName"] as? String,
              let connectionCode = data["connectionCode"] as? String else {
            return nil
        }
        return CalendarSharingProfile(
            userID: userID,
            displayName: displayName,
            connectionCode: connectionCode
        )
    }

    static func request(
        id: String,
        data: [String: Any]
    ) -> CalendarConnectionRequest? {
        guard let senderID = data["senderID"] as? String,
              let senderDisplayName = data["senderDisplayName"] as? String,
              let recipientID = data["recipientID"] as? String,
              let statusRaw = data["status"] as? String,
              let status = CalendarConnectionRequestStatus(rawValue: statusRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        return CalendarConnectionRequest(
            id: id,
            senderID: senderID,
            senderDisplayName: senderDisplayName,
            recipientID: recipientID,
            status: status,
            createdAt: createdAt
        )
    }

    static func connection(
        id: String,
        data: [String: Any]
    ) -> CalendarConnection? {
        guard let ownerID = data["ownerID"] as? String,
              let ownerDisplayName = data["ownerDisplayName"] as? String,
              let viewerID = data["viewerID"] as? String,
              let viewerDisplayName = data["viewerDisplayName"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        let sharedEventTypes = SharedEventTypeSelection(
            period: data["sharedPeriod"] as? Bool ?? true,
            pill: data["sharedPill"] as? Bool ?? true,
            love: data["sharedLove"] as? Bool ?? true
        )
        return CalendarConnection(
            id: id,
            ownerID: ownerID,
            ownerDisplayName: ownerDisplayName,
            viewerID: viewerID,
            viewerDisplayName: viewerDisplayName,
            sharedEventTypes: sharedEventTypes,
            createdAt: createdAt
        )
    }
}
