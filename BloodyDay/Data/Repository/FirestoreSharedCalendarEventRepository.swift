//
//  FirestoreSharedCalendarEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreSharedCalendarEventRepository: SharedCalendarEventRepository {
    private let database: Firestore

    init(database: Firestore = .firestore()) {
        self.database = database
    }

    func observeSnapshot(
        connectionID: String,
        onChange: @escaping (Result<SharedCalendarSnapshot, Error>) -> Void
    ) -> CalendarConnectionObservation {
        let observation = FirestoreSharedCalendarSnapshotObservation(
            onChange: onChange
        )
        let connectionReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connectionID)

        let eventListener = connectionReference
            .collection(FirestoreCalendarSharingMapper.Collection.events)
            .addSnapshotListener { [observation] snapshot, error in
                if let error {
                    observation.fail(error)
                    return
                }
                guard let snapshot else { return }
                if snapshot.metadata.isFromCache,
                   snapshot.documents.isEmpty {
                    return
                }

                let events = snapshot.documents
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
                    }
                observation.update(events: events)
            }

        let pillCycleListener = connectionReference
            .collection(
                FirestoreCalendarSharingMapper.Collection.pillCycles
            )
            .addSnapshotListener { [observation] snapshot, error in
                if let error {
                    observation.fail(error)
                    return
                }
                guard let snapshot else { return }
                if snapshot.metadata.isFromCache,
                   snapshot.documents.isEmpty {
                    return
                }

                let pillCycles = snapshot.documents
                    .compactMap {
                        FirestoreCalendarSharingMapper.sharedPillCycle(
                            id: $0.documentID,
                            data: $0.data()
                        )
                    }
                    .sorted { $0.startDay < $1.startDay }
                observation.update(pillCycles: pillCycles)
            }

        observation.setListeners(
            eventListener: eventListener,
            pillCycleListener: pillCycleListener
        )
        return CalendarConnectionObservation {
            observation.cancel()
        }
    }
}

private final class FirestoreSharedCalendarSnapshotObservation:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let onChange: (Result<SharedCalendarSnapshot, Error>) -> Void
    private var eventListener: ListenerRegistration?
    private var pillCycleListener: ListenerRegistration?
    private var events: [SharedCalendarEvent]?
    private var pillCycles: [SharedPillCycleMetadata]?
    private var isCancelled = false

    init(
        onChange: @escaping (Result<SharedCalendarSnapshot, Error>) -> Void
    ) {
        self.onChange = onChange
    }

    func setListeners(
        eventListener: ListenerRegistration,
        pillCycleListener: ListenerRegistration
    ) {
        lock.withLock {
            guard isCancelled == false else {
                eventListener.remove()
                pillCycleListener.remove()
                return
            }
            self.eventListener = eventListener
            self.pillCycleListener = pillCycleListener
        }
    }

    func update(events: [SharedCalendarEvent]) {
        let snapshot = lock.withLock {
            self.events = events
            return resolvedSnapshot()
        }
        if let snapshot {
            onChange(.success(snapshot))
        }
    }

    func update(pillCycles: [SharedPillCycleMetadata]) {
        let snapshot = lock.withLock {
            self.pillCycles = pillCycles
            return resolvedSnapshot()
        }
        if let snapshot {
            onChange(.success(snapshot))
        }
    }

    func fail(_ error: Error) {
        let shouldNotify = lock.withLock { isCancelled == false }
        if shouldNotify {
            onChange(.failure(error))
        }
    }

    func cancel() {
        lock.withLock {
            isCancelled = true
            eventListener?.remove()
            pillCycleListener?.remove()
            eventListener = nil
            pillCycleListener = nil
        }
    }

    private func resolvedSnapshot() -> SharedCalendarSnapshot? {
        guard isCancelled == false,
              let events,
              let pillCycles else {
            return nil
        }
        return SharedCalendarSnapshot(
            events: events,
            pillCycles: pillCycles
        )
    }
}
