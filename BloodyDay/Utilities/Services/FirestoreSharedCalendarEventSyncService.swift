//
//  FirestoreSharedCalendarEventSyncService.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreSharedCalendarEventSyncService: SharedCalendarEventSyncing {
    private let database: Firestore
    private let calendar: Calendar

    init(
        database: Firestore = .firestore(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.database = database
        self.calendar = calendar
    }

    func syncOwnedEvents(
        _ events: [UserEvent],
        pillCycles: [PillCycleInfo],
        connection: CalendarConnection,
        computationSettings: SharedCalendarComputationSettings
    ) async throws {
        let publicationVersion = UUID().uuidString
        let connectionReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connection.id)
        let collection = connectionReference
            .collection(FirestoreCalendarSharingMapper.Collection.events)
        let pillCycleCollection = connectionReference.collection(
            FirestoreCalendarSharingMapper.Collection.pillCycles
        )
        let connectionSnapshot = try await connectionReference.getDocument()
        let previousPublicationVersion = connectionSnapshot.data()
            .flatMap(
                FirestoreCalendarSharingMapper.publicationMetadata
            )?
            .version
        let existingSnapshot = try await collection.getDocuments()
        let existingPillCycleSnapshot = try await pillCycleCollection
            .getDocuments()
        let desiredEvents = events.filter {
            connection.sharedEventTypes.includes($0.type)
        }
        var eventSetMutations: [FirestoreSharedCalendarMutation] = []
        for event in desiredEvents {
            let documentID = "\(publicationVersion)_\(event.id.uuidString)"
            let data = FirestoreCalendarSharingMapper.sharedEventData(
                event,
                ownerID: connection.ownerID,
                publicationVersion: publicationVersion,
                calendar: calendar
            )
            eventSetMutations.append(
                .set(
                    reference: collection.document(documentID),
                    data: data
                )
            )
        }

        let sharedPillCycleIDs = Set(
            desiredEvents.compactMap { event -> UUID? in
                guard event.type == .pill else { return nil }
                return event.pillCycleID
            }
        )
        var desiredPillCycleData: [String: [String: Any]] = [:]
        for cycle in pillCycles where sharedPillCycleIDs.contains(cycle.id) {
            guard let data = FirestoreCalendarSharingMapper
                .sharedPillCycleData(
                    cycle,
                    ownerID: connection.ownerID,
                    publicationVersion: publicationVersion,
                    calendar: calendar
                ) else {
                continue
            }
            desiredPillCycleData[cycle.id.uuidString] = data
        }
        var pillCycleSetMutations: [FirestoreSharedCalendarMutation] = []
        for (cycleID, data) in desiredPillCycleData {
            let documentID = "\(publicationVersion)_\(cycleID)"
            pillCycleSetMutations.append(
                .set(
                    reference: pillCycleCollection.document(documentID),
                    data: data
                )
            )
        }

        try await commit(
            pillCycleSetMutations + eventSetMutations
        )

        try await connectionReference.updateData(
            FirestoreCalendarSharingMapper.publicationData(
                version: publicationVersion,
                eventCount: desiredEvents.count,
                pillCycleCount: desiredPillCycleData.count,
                connection: connection,
                computationSettings: computationSettings
            )
        )

        let staleMutations = existingSnapshot.documents.compactMap {
            staleMutation(
                document: $0,
                previousPublicationVersion: previousPublicationVersion
            )
        } + existingPillCycleSnapshot.documents.compactMap {
            staleMutation(
                document: $0,
                previousPublicationVersion: previousPublicationVersion
            )
        }
        do {
            try await commit(staleMutations)
        } catch {
            #if DEBUG
            print("[SharedCalendarSync] stale publication cleanup failed: \(error)")
            #endif
        }
    }

    private func commit(
        _ mutations: [FirestoreSharedCalendarMutation]
    ) async throws {
        for chunk in mutations.chunked(maxCount: 450) {
            let batch = database.batch()
            for mutation in chunk {
                switch mutation {
                case .set(let reference, let data):
                    batch.setData(data, forDocument: reference)
                case .delete(let reference):
                    batch.deleteDocument(reference)
                }
            }
            try await batch.commit()
        }
    }

    private func staleMutation(
        document: QueryDocumentSnapshot,
        previousPublicationVersion: String?
    ) -> FirestoreSharedCalendarMutation? {
        let documentVersion = FirestoreCalendarSharingMapper
            .publicationVersion(in: document.data())
        let belongsToPreviousPublication = previousPublicationVersion.map {
            documentVersion == $0
        } ?? (documentVersion == nil)
        guard belongsToPreviousPublication else { return nil }
        return .delete(reference: document.reference)
    }
}

private enum FirestoreSharedCalendarMutation {
    case set(reference: DocumentReference, data: [String: Any])
    case delete(reference: DocumentReference)
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maxCount).map {
            Array(self[$0..<Swift.min($0 + maxCount, count)])
        }
    }
}
