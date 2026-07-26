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
        let connectionReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connection.id)
        try await connectionReference.updateData(
            FirestoreCalendarSharingMapper.computationSettingsData(
                computationSettings,
                ownerID: connection.ownerID
            )
        )
        let collection = connectionReference
            .collection(FirestoreCalendarSharingMapper.Collection.events)
        let pillCycleCollection = connectionReference.collection(
            FirestoreCalendarSharingMapper.Collection.pillCycles
        )
        let existingSnapshot = try await collection.getDocuments()
        let existingPillCycleSnapshot = try await pillCycleCollection
            .getDocuments()
        let desiredEvents = events.filter {
            connection.sharedEventTypes.includes($0.type)
        }
        let desiredIDs = Set(desiredEvents.map { $0.id.uuidString })
        let existingByID = Dictionary(
            uniqueKeysWithValues: existingSnapshot.documents.map {
                ($0.documentID, $0.data())
            }
        )

        var eventSetMutations: [FirestoreSharedCalendarMutation] = []
        var eventDeleteMutations: [FirestoreSharedCalendarMutation] = []
        for event in desiredEvents {
            let documentID = event.id.uuidString
            let data = FirestoreCalendarSharingMapper.sharedEventData(
                event,
                ownerID: connection.ownerID,
                calendar: calendar
            )
            if FirestoreCalendarSharingMapper.sharedEventDataMatches(
                existingByID[documentID],
                expected: data
            ) == false {
                eventSetMutations.append(
                    .set(
                        reference: collection.document(documentID),
                        data: data
                    )
                )
            }
        }

        for existingID in existingByID.keys where desiredIDs.contains(existingID) == false {
            eventDeleteMutations.append(
                .delete(reference: collection.document(existingID))
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
                    calendar: calendar
                ) else {
                continue
            }
            desiredPillCycleData[cycle.id.uuidString] = data
        }
        let existingPillCyclesByID = Dictionary(
            uniqueKeysWithValues: existingPillCycleSnapshot.documents.map {
                ($0.documentID, $0.data())
            }
        )

        var pillCycleSetMutations: [FirestoreSharedCalendarMutation] = []
        var pillCycleDeleteMutations: [FirestoreSharedCalendarMutation] = []
        for (documentID, data) in desiredPillCycleData
        where FirestoreCalendarSharingMapper.sharedPillCycleDataMatches(
            existingPillCyclesByID[documentID],
            expected: data
        ) == false {
            pillCycleSetMutations.append(
                .set(
                    reference: pillCycleCollection.document(documentID),
                    data: data
                )
            )
        }
        for existingID in existingPillCyclesByID.keys
        where desiredPillCycleData[existingID] == nil {
            pillCycleDeleteMutations.append(
                .delete(reference: pillCycleCollection.document(existingID))
            )
        }

        let mutations = pillCycleSetMutations
            + eventSetMutations
            + eventDeleteMutations
            + pillCycleDeleteMutations
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
