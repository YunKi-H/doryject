//
//  FirestoreSharedCalendarEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore

final class FirestoreSharedCalendarEventRepository: SharedCalendarEventRepository {
    private let database: Firestore

    init(database: Firestore = .firestore()) {
        self.database = database
    }

    func observeEvents(
        connectionID: String,
        onChange: @escaping (Result<[SharedCalendarEvent], Error>) -> Void
    ) -> CalendarConnectionObservation {
        let listener = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connectionID)
            .collection(FirestoreCalendarSharingMapper.Collection.events)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let events = snapshot?.documents
                    .compactMap {
                        FirestoreCalendarSharingMapper.sharedEvent(
                            id: $0.documentID,
                            data: $0.data()
                        )
                    }
                    .sorted {
                        if $0.day == $1.day {
                            return $0.type.rawValue < $1.type.rawValue
                        }
                        return $0.day < $1.day
                    } ?? []
                onChange(.success(events))
            }

        return CalendarConnectionObservation {
            listener.remove()
        }
    }
}
