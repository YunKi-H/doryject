//
//  FirestoreCalendarRequestStore.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirestoreCalendarRequestStore {
    private let database: Firestore
    private let authenticatedUserID: () -> String?

    init(
        database: Firestore,
        authenticatedUserID: @escaping () -> String? = {
            Auth.auth().currentUser?.uid
        }
    ) {
        self.database = database
        self.authenticatedUserID = authenticatedUserID
    }

    func incomingRequests(
        for userID: String
    ) async throws -> [CalendarConnectionRequest] {
        let snapshot = try await incomingRequestQuery(
            for: userID
        ).getDocuments()
        return Self.pendingRequests(in: snapshot)
    }

    func observeIncomingRequests(
        for userID: String,
        onChange: @escaping (
            Result<[CalendarConnectionRequest], Error>
        ) -> Void
    ) -> CalendarConnectionObservation {
        let listener = incomingRequestQuery(for: userID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                guard let snapshot else {
                    onChange(.success([]))
                    return
                }
                onChange(.success(Self.pendingRequests(in: snapshot)))
            }

        return CalendarConnectionObservation {
            listener.remove()
        }
    }

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws {
        let currentUserID = authenticatedUserID()
        #if DEBUG
        print(
            "[CalendarConnectionAuth] profileUID=\(profile.userID) "
                + "authUID=\(currentUserID ?? "nil")"
        )
        #endif
        guard currentUserID == profile.userID else {
            throw CalendarConnectionRepositoryError
                .authenticationStateMismatch
        }

        let normalizedCode = CalendarConnectionCodeGenerator.normalize(
            connectionCode
        )
        guard normalizedCode.count == 8 else {
            throw CalendarConnectionRepositoryError
                .invalidConnectionCode
        }

        let codeSnapshot = try await database
            .collection(
                FirestoreCalendarSharingMapper.Collection.connectionCodes
            )
            .document(normalizedCode)
            .getDocument()
        guard let recipientID =
                codeSnapshot.data()?["userID"] as? String else {
            throw CalendarConnectionRepositoryError
                .connectionCodeNotFound
        }
        guard recipientID != profile.userID else {
            throw CalendarConnectionRepositoryError.cannotConnectToSelf
        }

        let requestID = Self.pairIdentifier(
            profile.userID,
            recipientID
        )
        let existingRequest = try await existingRequest(
            id: requestID,
            userID: profile.userID
        )
        try validateSubmission(
            existingRequest: existingRequest,
            requesterID: profile.userID
        )

        try await requestsCollection
            .document(requestID)
            .setData(
                FirestoreCalendarSharingMapper.pendingRequestData(
                    sender: profile,
                    recipientID: recipientID
                )
            )
    }

    func decline(
        _ request: CalendarConnectionRequest,
        recipientID: String
    ) async throws {
        guard request.recipientID == recipientID else {
            throw CalendarConnectionRepositoryError
                .requestRecipientMismatch
        }
        try await requestsCollection
            .document(request.id)
            .updateData(
                FirestoreCalendarSharingMapper.requestStatusData(.declined)
            )
    }

    private var requestsCollection: CollectionReference {
        database.collection(
            FirestoreCalendarSharingMapper.Collection.requests
        )
    }

    private func incomingRequestQuery(
        for userID: String
    ) -> Query {
        requestsCollection.whereField(
            "recipientID",
            isEqualTo: userID
        )
    }

    private func existingRequest(
        id requestID: String,
        userID: String
    ) async throws -> CalendarConnectionRequest? {
        async let sentSnapshot = participantRequestQuery(
            participantField: "senderID",
            userID: userID
        ).getDocuments()
        async let receivedSnapshot = participantRequestQuery(
            participantField: "recipientID",
            userID: userID
        ).getDocuments()
        let (sent, received) = try await (
            sentSnapshot,
            receivedSnapshot
        )

        return (sent.documents + received.documents)
            .first { $0.documentID == requestID }
            .flatMap(Self.request)
    }

    private func participantRequestQuery(
        participantField: String,
        userID: String
    ) -> Query {
        requestsCollection
            .whereField(participantField, isEqualTo: userID)
    }

    private func validateSubmission(
        existingRequest: CalendarConnectionRequest?,
        requesterID: String
    ) throws {
        switch CalendarConnectionRequestPolicy.submissionDecision(
            existingRequest: existingRequest,
            requesterID: requesterID
        ) {
        case .submit:
            return
        case .incomingRequestExists:
            throw CalendarConnectionRepositoryError
                .incomingRequestAlreadyExists
        case .alreadyConnected:
            throw CalendarConnectionRepositoryError.alreadyConnected
        case .reverseRequestUnavailable:
            throw CalendarConnectionRepositoryError
                .reverseRequestUnavailable
        case .invalidRequest:
            throw CalendarConnectionRepositoryError
                .invalidServerResponse
        }
    }

    private static func pendingRequests(
        in snapshot: QuerySnapshot
    ) -> [CalendarConnectionRequest] {
        snapshot.documents
            .compactMap(request)
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func request(
        _ document: QueryDocumentSnapshot
    ) -> CalendarConnectionRequest? {
        FirestoreCalendarSharingMapper.request(
            id: document.documentID,
            data: document.data()
        )
    }

    private static func pairIdentifier(
        _ firstUserID: String,
        _ secondUserID: String
    ) -> String {
        [firstUserID, secondUserID]
            .sorted()
            .joined(separator: "_")
    }
}
