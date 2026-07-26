//
//  FirestoreCalendarConnectionRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreCalendarConnectionRepository: CalendarConnectionRepository {
    private let database: Firestore
    private let codeGenerator: () -> String

    init(
        database: Firestore = .firestore(),
        codeGenerator: @escaping () -> String = CalendarConnectionCodeGenerator.make
    ) {
        self.database = database
        self.codeGenerator = codeGenerator
    }

    func ensureProfile(for user: AuthenticatedUser) async throws -> CalendarSharingProfile {
        let userReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.users)
            .document(user.id)
        let existingSnapshot = try await userReference.getDocument()
        if let data = existingSnapshot.data(),
           let profile = FirestoreCalendarSharingMapper.profile(userID: user.id, data: data) {
            return profile
        }

        let displayName = normalizedDisplayName(for: user)
        for _ in 0..<5 {
            let code = codeGenerator()
            do {
                let value = try await createProfileIfNeeded(
                    userID: user.id,
                    displayName: displayName,
                    proposedCode: code
                )
                guard let resolvedCode = value as? String else {
                    throw CalendarConnectionRepositoryError.invalidServerResponse
                }
                return CalendarSharingProfile(
                    userID: user.id,
                    displayName: displayName,
                    connectionCode: resolvedCode
                )
            } catch {
                let nsError = error as NSError
                if nsError.domain == Self.transactionErrorDomain,
                   nsError.code == Self.connectionCodeCollisionErrorCode {
                    continue
                }
                throw error
            }
        }

        throw CalendarConnectionRepositoryError.connectionCodeGenerationFailed
    }

    func activeConnection(for userID: String) async throws -> CalendarConnection? {
        let membershipSnapshot = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(userID)
            .getDocument()
        guard let connectionID = membershipSnapshot.data()?["connectionID"] as? String else {
            if membershipSnapshot.metadata.isFromCache {
                throw CalendarConnectionRepositoryError
                    .cachedConnectionUnavailable
            }
            return nil
        }
        let document = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connectionID)
            .getDocument()
        guard let data = document.data() else {
            if document.metadata.isFromCache {
                throw CalendarConnectionRepositoryError
                    .cachedConnectionUnavailable
            }
            return nil
        }
        guard let connection = FirestoreCalendarSharingMapper.connection(
            id: document.documentID,
            data: data
        ) else {
            throw CalendarConnectionRepositoryError.invalidServerResponse
        }
        return connection
    }

    func incomingRequests(for userID: String) async throws -> [CalendarConnectionRequest] {
        let snapshot = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .whereField("recipientID", isEqualTo: userID)
            .getDocuments()

        return snapshot.documents
            .compactMap {
                FirestoreCalendarSharingMapper.request(
                    id: $0.documentID,
                    data: $0.data()
                )
            }
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func observeActiveConnection(
        for userID: String,
        onChange: @escaping (Result<CalendarConnection?, Error>) -> Void
    ) -> CalendarConnectionObservation {
        let listeners = FirestoreActiveConnectionListeners()
        let membershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(userID)

        let membershipListener = membershipReference.addSnapshotListener { [database] snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }

            listeners.replaceConnectionListener(nil)

            guard let connectionID = snapshot?.data()?["connectionID"] as? String else {
                if snapshot?.metadata.isFromCache == true {
                    return
                }
                onChange(.success(nil))
                return
            }

            let connectionListener = database
                .collection(FirestoreCalendarSharingMapper.Collection.connections)
                .document(connectionID)
                .addSnapshotListener { document, error in
                    if let error {
                        onChange(.failure(error))
                        return
                    }
                    guard let document else {
                        onChange(.success(nil))
                        return
                    }
                    guard document.metadata.hasPendingWrites == false else {
                        return
                    }
                    guard let data = document.data() else {
                        if document.metadata.isFromCache {
                            return
                        }
                        onChange(.success(nil))
                        return
                    }
                    guard let connection = FirestoreCalendarSharingMapper.connection(
                        id: document.documentID,
                        data: data
                    ) else {
                        onChange(.failure(
                            CalendarConnectionRepositoryError
                                .invalidServerResponse
                        ))
                        return
                    }
                    onChange(.success(connection))
                }
            listeners.replaceConnectionListener(connectionListener)
        }
        listeners.setMembershipListener(membershipListener)

        return CalendarConnectionObservation {
            listeners.cancel()
        }
    }

    func observeIncomingRequests(
        for userID: String,
        onChange: @escaping (Result<[CalendarConnectionRequest], Error>) -> Void
    ) -> CalendarConnectionObservation {
        let listener = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .whereField("recipientID", isEqualTo: userID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let requests = snapshot?.documents
                    .compactMap {
                        FirestoreCalendarSharingMapper.request(
                            id: $0.documentID,
                            data: $0.data()
                        )
                    }
                    .filter { $0.status == .pending }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                onChange(.success(requests))
            }

        return CalendarConnectionObservation {
            listener.remove()
        }
    }

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws {
        let normalizedCode = CalendarConnectionCodeGenerator.normalize(connectionCode)
        guard normalizedCode.count == 8 else {
            throw CalendarConnectionRepositoryError.invalidConnectionCode
        }

        let codeSnapshot = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.connectionCodes)
            .document(normalizedCode)
            .getDocument()
        guard let recipientID = codeSnapshot.data()?["userID"] as? String else {
            throw CalendarConnectionRepositoryError.connectionCodeNotFound
        }
        guard recipientID != profile.userID else {
            throw CalendarConnectionRepositoryError.cannotConnectToSelf
        }

        let requestID = Self.pairIdentifier(profile.userID, recipientID)
        let requestReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(requestID)
        if let existingRequest = try await existingRequest(
            id: requestID,
            userID: profile.userID
        ) {
            if existingRequest.senderID != profile.userID {
                switch existingRequest.status {
                case .pending:
                    throw CalendarConnectionRepositoryError
                        .incomingRequestAlreadyExists
                case .accepted:
                    throw CalendarConnectionRepositoryError
                        .alreadyConnected
                case .declined:
                    throw CalendarConnectionRepositoryError
                        .reverseRequestUnavailable
                }
            }
            if existingRequest.status == .accepted {
                throw CalendarConnectionRepositoryError.alreadyConnected
            }
        }

        try await requestReference
            .setData([
                "senderID": profile.userID,
                "senderDisplayName": profile.displayName,
                "recipientID": recipientID,
                "status": CalendarConnectionRequestStatus.pending.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    private func existingRequest(
        id requestID: String,
        userID: String
    ) async throws -> CalendarConnectionRequest? {
        let collection = database.collection(
            FirestoreCalendarSharingMapper.Collection.requests
        )
        async let sentSnapshot = collection
            .whereField("senderID", isEqualTo: userID)
            .getDocuments()
        async let receivedSnapshot = collection
            .whereField("recipientID", isEqualTo: userID)
            .getDocuments()
        let (sent, received) = try await (
            sentSnapshot,
            receivedSnapshot
        )

        return (sent.documents + received.documents)
            .first { $0.documentID == requestID }
            .flatMap {
                FirestoreCalendarSharingMapper.request(
                    id: $0.documentID,
                    data: $0.data()
                )
            }
    }

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection {
        guard request.recipientID == recipient.userID else {
            throw CalendarConnectionRepositoryError.requestRecipientMismatch
        }
        guard ownerID == request.senderID || ownerID == recipient.userID else {
            throw CalendarConnectionRepositoryError.invalidOwner
        }

        let ownerIsRecipient = ownerID == recipient.userID
        let ownerDisplayName = ownerIsRecipient
            ? recipient.displayName
            : request.senderDisplayName
        let viewerID = ownerIsRecipient ? request.senderID : recipient.userID
        let viewerDisplayName = ownerIsRecipient
            ? request.senderDisplayName
            : recipient.displayName
        let requestReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(request.id)
        let connectionReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(request.id)
        let senderMembershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(request.senderID)
        let recipientMembershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(recipient.userID)

        let batch = database.batch()
        batch.updateData(
            ["status": CalendarConnectionRequestStatus.accepted.rawValue],
            forDocument: requestReference
        )
        batch.setData([
            "ownerID": ownerID,
            "ownerDisplayName": ownerDisplayName,
            "viewerID": viewerID,
            "viewerDisplayName": viewerDisplayName,
            "participantIDs": [ownerID, viewerID],
            "sharedPeriod": true,
            "sharedPill": true,
            "sharedLove": true,
            "status": "active",
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: connectionReference)
        let membershipData: [String: Any] = [
            "connectionID": request.id,
            "participantIDs": [request.senderID, recipient.userID],
            "createdAt": FieldValue.serverTimestamp()
        ]
        var senderMembershipData = membershipData
        senderMembershipData["userID"] = request.senderID
        var recipientMembershipData = membershipData
        recipientMembershipData["userID"] = recipient.userID
        batch.setData(
            senderMembershipData,
            forDocument: senderMembershipReference
        )
        batch.setData(
            recipientMembershipData,
            forDocument: recipientMembershipReference
        )
        try await batch.commit()

        return CalendarConnection(
            id: request.id,
            ownerID: ownerID,
            ownerDisplayName: ownerDisplayName,
            viewerID: viewerID,
            viewerDisplayName: viewerDisplayName,
            sharedEventTypes: SharedEventTypeSelection(),
            createdAt: .now
        )
    }

    func decline(
        _ request: CalendarConnectionRequest,
        recipientID: String
    ) async throws {
        guard request.recipientID == recipientID else {
            throw CalendarConnectionRepositoryError.requestRecipientMismatch
        }
        try await database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(request.id)
            .updateData([
                "status": CalendarConnectionRequestStatus.declined.rawValue
            ])
    }

    func updateSharedEventTypes(
        connectionID: String,
        ownerID: String,
        selection: SharedEventTypeSelection
    ) async throws {
        try await database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connectionID)
            .updateData([
                "sharedPeriod": selection.period,
                "sharedPill": selection.pill,
                "sharedLove": selection.love,
                "sharingUpdatedAt": FieldValue.serverTimestamp(),
                "sharingUpdatedBy": ownerID
            ])
    }

    func disconnect(
        _ connection: CalendarConnection,
        requestedBy userID: String
    ) async throws {
        guard connection.ownerID == userID
                || connection.viewerID == userID else {
            throw CalendarConnectionRepositoryError.notConnectionParticipant
        }

        let connectionReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connection.id)
        try await markConnectionTerminating(
            connectionReference,
            requestedBy: userID
        )
        try await deleteSharedData(connectionReference: connectionReference)
        try await deleteConnectionDocuments(
            connection,
            connectionReference: connectionReference,
            requestedBy: userID
        )
    }

    private func createProfileIfNeeded(
        userID: String,
        displayName: String,
        proposedCode: String
    ) async throws -> Any? {
        let userReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.users)
            .document(userID)
        let codeReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connectionCodes)
            .document(proposedCode)

        return try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let userSnapshot = try transaction.getDocument(userReference)
                let codeSnapshot = try transaction.getDocument(codeReference)

                if let existingCode = userSnapshot.data()?["connectionCode"] as? String {
                    return existingCode
                }
                guard codeSnapshot.exists == false else {
                    errorPointer?.pointee = NSError(
                        domain: Self.transactionErrorDomain,
                        code: Self.connectionCodeCollisionErrorCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Connection code collision"
                        ]
                    )
                    return nil
                }

                transaction.setData([
                    "displayName": displayName,
                    "connectionCode": proposedCode,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: userReference)
                transaction.setData([
                    "userID": userID
                ], forDocument: codeReference)
                return proposedCode
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func markConnectionTerminating(
        _ connectionReference: DocumentReference,
        requestedBy userID: String
    ) async throws {
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(connectionReference)
                guard let data = snapshot.data(),
                      let participantIDs = data["participantIDs"] as? [String],
                      participantIDs.contains(userID) else {
                    throw CalendarConnectionRepositoryError
                        .notConnectionParticipant
                }

                if data["status"] as? String != Self.terminatingStatus {
                    transaction.updateData([
                        "status": Self.terminatingStatus,
                        "terminationRequestedBy": userID,
                        "terminationStartedAt": FieldValue.serverTimestamp()
                    ], forDocument: connectionReference)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func deleteSharedData(
        connectionReference: DocumentReference
    ) async throws {
        try await deleteDocuments(
            in: connectionReference.collection(
                FirestoreCalendarSharingMapper.Collection.events
            )
        )
        try await deleteDocuments(
            in: connectionReference.collection(
                FirestoreCalendarSharingMapper.Collection.pillCycles
            )
        )
    }

    private func deleteDocuments(
        in collection: CollectionReference
    ) async throws {
        while true {
            let snapshot = try await collection
                .limit(to: Self.disconnectBatchSize)
                .getDocuments()
            guard snapshot.documents.isEmpty == false else { return }

            let batch = database.batch()
            snapshot.documents.forEach {
                batch.deleteDocument($0.reference)
            }
            try await batch.commit()
        }
    }

    private func deleteConnectionDocuments(
        _ connection: CalendarConnection,
        connectionReference: DocumentReference,
        requestedBy userID: String
    ) async throws {
        let requestReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(connection.id)
        let ownerMembershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(connection.ownerID)
        let viewerMembershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(connection.viewerID)

        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let connectionSnapshot = try transaction
                    .getDocument(connectionReference)
                let requestSnapshot = try transaction
                    .getDocument(requestReference)
                let ownerMembershipSnapshot = try transaction
                    .getDocument(ownerMembershipReference)
                let viewerMembershipSnapshot = try transaction
                    .getDocument(viewerMembershipReference)

                guard let data = connectionSnapshot.data(),
                      data["status"] as? String == Self.terminatingStatus,
                      let participantIDs = data["participantIDs"] as? [String],
                      participantIDs.contains(userID) else {
                    throw CalendarConnectionRepositoryError
                        .connectionTerminationUnavailable
                }

                if requestSnapshot.exists {
                    transaction.deleteDocument(requestReference)
                }
                if ownerMembershipSnapshot.exists {
                    transaction.deleteDocument(ownerMembershipReference)
                }
                if viewerMembershipSnapshot.exists {
                    transaction.deleteDocument(viewerMembershipReference)
                }
                transaction.deleteDocument(connectionReference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func normalizedDisplayName(for user: AuthenticatedUser) -> String {
        let trimmedName = user.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedName, trimmedName.isEmpty == false else {
            return "B-Day 사용자"
        }
        return trimmedName
    }

    private static func pairIdentifier(_ firstUserID: String, _ secondUserID: String) -> String {
        [firstUserID, secondUserID]
            .sorted()
            .joined(separator: "_")
    }

    private static let transactionErrorDomain = "BloodyDay.CalendarConnectionTransaction"
    private static let connectionCodeCollisionErrorCode = 1
    private static let terminatingStatus = "terminating"
    private static let disconnectBatchSize = 400
}

private final class FirestoreActiveConnectionListeners: @unchecked Sendable {
    private let lock = NSLock()
    private var membershipListener: ListenerRegistration?
    private var connectionListener: ListenerRegistration?
    private var isCancelled = false

    func setMembershipListener(_ listener: ListenerRegistration) {
        lock.withLock {
            guard isCancelled == false else {
                listener.remove()
                return
            }
            membershipListener = listener
        }
    }

    func replaceConnectionListener(_ listener: ListenerRegistration?) {
        lock.withLock {
            connectionListener?.remove()
            guard isCancelled == false else {
                listener?.remove()
                connectionListener = nil
                return
            }
            connectionListener = listener
        }
    }

    func cancel() {
        lock.withLock {
            isCancelled = true
            membershipListener?.remove()
            connectionListener?.remove()
            membershipListener = nil
            connectionListener = nil
        }
    }
}

private enum CalendarConnectionCodeGenerator {
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func make() -> String {
        String((0..<8).compactMap { _ in characters.randomElement() })
    }

    static func normalize(_ code: String) -> String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { characters.contains($0) }
    }
}

enum CalendarConnectionRepositoryError: LocalizedError {
    case invalidServerResponse
    case connectionCodeCollision
    case connectionCodeGenerationFailed
    case invalidConnectionCode
    case connectionCodeNotFound
    case cannotConnectToSelf
    case requestRecipientMismatch
    case requestUnavailable
    case incomingRequestAlreadyExists
    case reverseRequestUnavailable
    case invalidOwner
    case alreadyConnected
    case cachedConnectionUnavailable
    case notConnectionParticipant
    case connectionTerminationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidServerResponse:
            return "서버에서 연결 정보를 확인하지 못했어요."
        case .connectionCodeCollision, .connectionCodeGenerationFailed:
            return "연결 ID를 만들지 못했어요. 잠시 후 다시 시도해주세요."
        case .invalidConnectionCode:
            return "상대방의 연결 ID를 입력해주세요."
        case .connectionCodeNotFound:
            return "일치하는 연결 ID를 찾지 못했어요."
        case .cannotConnectToSelf:
            return "내 연결 ID로는 요청할 수 없어요."
        case .requestRecipientMismatch:
            return "이 연결 요청을 처리할 권한이 없어요."
        case .requestUnavailable:
            return "이미 처리됐거나 취소된 연결 요청이에요."
        case .incomingRequestAlreadyExists:
            return "상대방이 이미 연결 요청을 보냈어요. 받은 요청에서 수락해주세요."
        case .reverseRequestUnavailable:
            return "상대방이 보낸 이전 요청이 거절된 상태예요. 상대방에게 다시 요청해달라고 알려주세요."
        case .invalidOwner:
            return "사용할 캘린더를 확인하지 못했어요."
        case .alreadyConnected:
            return "두 사람 중 한 명이 이미 다른 캘린더와 연결되어 있어요."
        case .cachedConnectionUnavailable:
            return "오프라인 상태라 최신 연결 정보를 확인하지 못했어요."
        case .notConnectionParticipant:
            return "이 캘린더 연결을 해제할 권한이 없어요."
        case .connectionTerminationUnavailable:
            return "연결 종료 상태를 확인하지 못했어요. 다시 시도해주세요."
        }
    }
}
