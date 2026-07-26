//
//  PreviewCalendarConnectionRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

final class PreviewCalendarConnectionRepository: CalendarConnectionRepository {
    private var connection: CalendarConnection?

    func ensureProfile(for user: AuthenticatedUser) async throws -> CalendarSharingProfile {
        CalendarSharingProfile(
            userID: user.id,
            displayName: user.displayName ?? "B-Day 사용자",
            connectionCode: "BDAY2026"
        )
    }

    func activeConnection(for userID: String) async throws -> CalendarConnection? {
        connection
    }

    func incomingRequests(for userID: String) async throws -> [CalendarConnectionRequest] {
        []
    }

    func observeActiveConnection(
        for userID: String,
        onChange: @escaping (Result<CalendarConnection?, Error>) -> Void
    ) -> CalendarConnectionObservation {
        onChange(.success(connection))
        return CalendarConnectionObservation()
    }

    func observeIncomingRequests(
        for userID: String,
        onChange: @escaping (Result<[CalendarConnectionRequest], Error>) -> Void
    ) -> CalendarConnectionObservation {
        onChange(.success([]))
        return CalendarConnectionObservation()
    }

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws {}

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection {
        let ownerIsRecipient = ownerID == recipient.userID
        let acceptedConnection = CalendarConnection(
            id: request.id,
            ownerID: ownerID,
            ownerDisplayName: ownerIsRecipient
                ? recipient.displayName
                : request.senderDisplayName,
            viewerID: ownerIsRecipient
                ? request.senderID
                : recipient.userID,
            viewerDisplayName: ownerIsRecipient
                ? request.senderDisplayName
                : recipient.displayName,
            sharedEventTypes: SharedEventTypeSelection(),
            createdAt: .now
        )
        connection = acceptedConnection
        return acceptedConnection
    }

    func decline(
        _ request: CalendarConnectionRequest,
        recipientID: String
    ) async throws {}

    func updateSharedEventTypes(
        connectionID: String,
        ownerID: String,
        selection: SharedEventTypeSelection
    ) async throws {
        guard let connection else { return }
        self.connection = CalendarConnection(
            id: connection.id,
            ownerID: connection.ownerID,
            ownerDisplayName: connection.ownerDisplayName,
            viewerID: connection.viewerID,
            viewerDisplayName: connection.viewerDisplayName,
            sharedEventTypes: selection,
            createdAt: connection.createdAt,
            computationSettings: connection.computationSettings
        )
    }

    func disconnect(
        _ connection: CalendarConnection,
        requestedBy userID: String
    ) async throws {
        self.connection = nil
    }
}
