//
//  FirestoreCalendarConnectionStore.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreCalendarConnectionStore {
    private let database: Firestore

    init(database: Firestore) {
        self.database = database
    }

    func activeConnection(
        for userID: String
    ) async throws -> CalendarConnection? {
        let membershipSnapshot = try await membershipsCollection
            .document(userID)
            .getDocument()
        guard let connectionID =
                membershipSnapshot.data()?["connectionID"] as? String else {
            if membershipSnapshot.metadata.isFromCache {
                throw CalendarConnectionRepositoryError
                    .cachedConnectionUnavailable
            }
            return nil
        }

        let document = try await connectionsCollection
            .document(connectionID)
            .getDocument()
        guard let data = document.data() else {
            if document.metadata.isFromCache {
                throw CalendarConnectionRepositoryError
                    .cachedConnectionUnavailable
            }
            return nil
        }
        guard let connection =
                FirestoreCalendarSharingMapper.connection(
                    id: document.documentID,
                    data: data
                ) else {
            throw CalendarConnectionRepositoryError
                .invalidServerResponse
        }
        return connection
    }

    func observeActiveConnection(
        for userID: String,
        onChange: @escaping (
            Result<CalendarConnection?, Error>
        ) -> Void
    ) -> CalendarConnectionObservation {
        let listeners = FirestoreActiveConnectionListeners()
        let membershipListener = membershipsCollection
            .document(userID)
            .addSnapshotListener { [database] snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                listeners.replaceConnectionListener(nil)
                guard let connectionID =
                        snapshot?.data()?["connectionID"] as? String else {
                    if snapshot?.metadata.isFromCache == true {
                        return
                    }
                    onChange(.success(nil))
                    return
                }

                let connectionListener = database
                    .collection(
                        FirestoreCalendarSharingMapper.Collection.connections
                    )
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
                        guard let connection =
                                FirestoreCalendarSharingMapper.connection(
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
                listeners.replaceConnectionListener(
                    connectionListener
                )
            }
        listeners.setMembershipListener(membershipListener)

        return CalendarConnectionObservation {
            listeners.cancel()
        }
    }

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection {
        guard request.recipientID == recipient.userID else {
            throw CalendarConnectionRepositoryError
                .requestRecipientMismatch
        }
        guard ownerID == request.senderID
                || ownerID == recipient.userID else {
            throw CalendarConnectionRepositoryError.invalidOwner
        }

        let ownerIsRecipient = ownerID == recipient.userID
        let ownerDisplayName = ownerIsRecipient
            ? recipient.displayName
            : request.senderDisplayName
        let viewerID = ownerIsRecipient
            ? request.senderID
            : recipient.userID
        let viewerDisplayName = ownerIsRecipient
            ? request.senderDisplayName
            : recipient.displayName
        let requestReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(request.id)
        let connectionReference = connectionsCollection
            .document(request.id)
        let senderMembershipReference = membershipsCollection
            .document(request.senderID)
        let recipientMembershipReference = membershipsCollection
            .document(recipient.userID)
        let connection = CalendarConnection(
            id: request.id,
            ownerID: ownerID,
            ownerDisplayName: ownerDisplayName,
            viewerID: viewerID,
            viewerDisplayName: viewerDisplayName,
            sharedEventTypes: SharedEventTypeSelection(),
            createdAt: .now
        )

        let batch = database.batch()
        batch.updateData(
            FirestoreCalendarSharingMapper.requestStatusData(.accepted),
            forDocument: requestReference
        )
        batch.setData(
            FirestoreCalendarSharingMapper.connectionData(connection),
            forDocument: connectionReference
        )
        batch.setData(
            FirestoreCalendarSharingMapper.membershipData(
                userID: request.senderID,
                connection: connection
            ),
            forDocument: senderMembershipReference
        )
        batch.setData(
            FirestoreCalendarSharingMapper.membershipData(
                userID: recipient.userID,
                connection: connection
            ),
            forDocument: recipientMembershipReference
        )
        try await batch.commit()

        return connection
    }

    func updateSharedEventTypes(
        connectionID: String,
        ownerID: String,
        selection: SharedEventTypeSelection
    ) async throws {
        try await connectionsCollection
            .document(connectionID)
            .updateData(
                FirestoreCalendarSharingMapper.sharedEventTypesData(
                    selection,
                    ownerID: ownerID
                )
            )
    }

    func disconnect(
        _ connection: CalendarConnection,
        requestedBy userID: String
    ) async throws {
        guard connection.role(for: userID) != nil else {
            throw CalendarConnectionRepositoryError
                .notConnectionParticipant
        }

        let connectionReference = connectionsCollection
            .document(connection.id)
        try await markConnectionTerminating(
            connectionReference,
            requestedBy: userID
        )
        try await deleteSharedData(
            connectionReference: connectionReference
        )
        try await deleteConnectionDocuments(
            connection,
            connectionReference: connectionReference
        )
    }

    private var connectionsCollection: CollectionReference {
        database.collection(
            FirestoreCalendarSharingMapper.Collection.connections
        )
    }

    private var membershipsCollection: CollectionReference {
        database.collection(
            FirestoreCalendarSharingMapper.Collection.memberships
        )
    }

    private func markConnectionTerminating(
        _ connectionReference: DocumentReference,
        requestedBy userID: String
    ) async throws {
        _ = try await database.runTransaction {
            transaction,
            errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(
                    connectionReference
                )
                guard let data = snapshot.data(),
                      let participantIDs =
                        data["participantIDs"] as? [String],
                      participantIDs.contains(userID) else {
                    throw CalendarConnectionRepositoryError
                        .notConnectionParticipant
                }

                if FirestoreCalendarSharingMapper.connectionStatus(
                    in: data
                ) != .terminating {
                    transaction.updateData(
                        FirestoreCalendarSharingMapper.terminationData(
                            requestedBy: userID
                        ),
                        forDocument: connectionReference
                    )
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
            guard snapshot.documents.isEmpty == false else {
                return
            }

            let batch = database.batch()
            snapshot.documents.forEach {
                batch.deleteDocument($0.reference)
            }
            try await batch.commit()
        }
    }

    private func deleteConnectionDocuments(
        _ connection: CalendarConnection,
        connectionReference: DocumentReference
    ) async throws {
        let requestReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(connection.id)
        let ownerMembershipReference = membershipsCollection
            .document(connection.ownerID)
        let viewerMembershipReference = membershipsCollection
            .document(connection.viewerID)

        let batch = database.batch()
        batch.deleteDocument(requestReference)
        batch.deleteDocument(ownerMembershipReference)
        batch.deleteDocument(viewerMembershipReference)
        batch.deleteDocument(connectionReference)
        try await batch.commit()
    }

    private static let disconnectBatchSize = 400
}

private final class FirestoreActiveConnectionListeners:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var membershipListener: ListenerRegistration?
    private var connectionListener: ListenerRegistration?
    private var isCancelled = false

    func setMembershipListener(
        _ listener: ListenerRegistration
    ) {
        lock.withLock {
            guard isCancelled == false else {
                listener.remove()
                return
            }
            membershipListener = listener
        }
    }

    func replaceConnectionListener(
        _ listener: ListenerRegistration?
    ) {
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
