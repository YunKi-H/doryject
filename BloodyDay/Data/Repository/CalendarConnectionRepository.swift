//
//  CalendarConnectionRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

protocol CalendarConnectionRepository {
    func ensureProfile(for user: AuthenticatedUser) async throws -> CalendarSharingProfile
    func activeConnection(for userID: String) async throws -> CalendarConnection?
    func incomingRequests(for userID: String) async throws -> [CalendarConnectionRequest]

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection

    func decline(_ request: CalendarConnectionRequest, recipientID: String) async throws

    func updateSharedEventTypes(
        connectionID: String,
        ownerID: String,
        selection: SharedEventTypeSelection
    ) async throws
}
