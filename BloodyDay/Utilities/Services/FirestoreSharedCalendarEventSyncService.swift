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
        let existingSnapshot = try await collection.getDocuments()
        let desiredEvents = events.filter {
            connection.sharedEventTypes.includes($0.type)
        }
        let desiredIDs = Set(desiredEvents.map { $0.id.uuidString })
        let existingByID = Dictionary(
            uniqueKeysWithValues: existingSnapshot.documents.map {
                ($0.documentID, $0.data())
            }
        )

        var mutations: [FirestoreEventMutation] = []
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
                mutations.append(.set(documentID: documentID, data: data))
            }
        }

        for existingID in existingByID.keys where desiredIDs.contains(existingID) == false {
            mutations.append(.delete(documentID: existingID))
        }

        for chunk in mutations.chunked(maxCount: 450) {
            let batch = database.batch()
            for mutation in chunk {
                switch mutation {
                case .set(let documentID, let data):
                    batch.setData(data, forDocument: collection.document(documentID))
                case .delete(let documentID):
                    batch.deleteDocument(collection.document(documentID))
                }
            }
            try await batch.commit()
        }
    }
}

private enum FirestoreEventMutation {
    case set(documentID: String, data: [String: Any])
    case delete(documentID: String)
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maxCount).map {
            Array(self[$0..<Swift.min($0 + maxCount, count)])
        }
    }
}
