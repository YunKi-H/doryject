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

        let connectionListener = connectionReference
            .addSnapshotListener { [observation] snapshot, error in
                if let error {
                    observation.fail(error)
                    return
                }
                guard let data = snapshot?.data() else { return }
                observation.update(
                    publication: FirestoreCalendarSharingMapper
                        .publicationMetadata(data),
                    legacyComputationSettings:
                        FirestoreCalendarSharingMapper
                            .computationSettings(data)
                )
            }

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

                observation.update(
                    eventDocuments: Dictionary(
                        uniqueKeysWithValues: snapshot.documents.map {
                            ($0.documentID, $0.data())
                        }
                    )
                )
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

                observation.update(
                    pillCycleDocuments: Dictionary(
                        uniqueKeysWithValues: snapshot.documents.map {
                            ($0.documentID, $0.data())
                        }
                    )
                )
            }

        observation.setListeners(
            connectionListener: connectionListener,
            eventListener: eventListener,
            pillCycleListener: pillCycleListener
        )
        return CalendarConnectionObservation {
            observation.cancel()
        }
    }
}

final class FirestoreSharedCalendarSnapshotObservation:
    @unchecked Sendable
{
    private let lock = NSLock()
    private let onChange: (Result<SharedCalendarSnapshot, Error>) -> Void
    private var connectionListener: ListenerRegistration?
    private var eventListener: ListenerRegistration?
    private var pillCycleListener: ListenerRegistration?
    private var publication: FirestoreSharedCalendarPublicationMetadata?
    private var legacyComputationSettings: SharedCalendarComputationSettings?
    private var eventDocuments: [String: [String: Any]]?
    private var pillCycleDocuments: [String: [String: Any]]?
    private var lastEmittedSnapshot: SharedCalendarSnapshot?
    private var isCancelled = false

    init(
        onChange: @escaping (Result<SharedCalendarSnapshot, Error>) -> Void
    ) {
        self.onChange = onChange
    }

    func setListeners(
        connectionListener: ListenerRegistration,
        eventListener: ListenerRegistration,
        pillCycleListener: ListenerRegistration
    ) {
        lock.withLock {
            guard isCancelled == false else {
                connectionListener.remove()
                eventListener.remove()
                pillCycleListener.remove()
                return
            }
            self.connectionListener = connectionListener
            self.eventListener = eventListener
            self.pillCycleListener = pillCycleListener
        }
    }

    func update(
        publication: FirestoreSharedCalendarPublicationMetadata?,
        legacyComputationSettings: SharedCalendarComputationSettings?
    ) {
        emitIfResolved {
            self.publication = publication
            self.legacyComputationSettings = legacyComputationSettings
        }
    }

    func update(eventDocuments: [String: [String: Any]]) {
        emitIfResolved {
            self.eventDocuments = eventDocuments
        }
    }

    func update(pillCycleDocuments: [String: [String: Any]]) {
        emitIfResolved {
            self.pillCycleDocuments = pillCycleDocuments
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
            connectionListener?.remove()
            eventListener?.remove()
            pillCycleListener?.remove()
            connectionListener = nil
            eventListener = nil
            pillCycleListener = nil
        }
    }

    private func emitIfResolved(_ update: () -> Void) {
        let snapshot = lock.withLock { () -> SharedCalendarSnapshot? in
            update()
            guard let resolved = resolvedSnapshot(),
                  resolved != lastEmittedSnapshot else {
                return nil
            }
            lastEmittedSnapshot = resolved
            return resolved
        }
        if let snapshot {
            onChange(.success(snapshot))
        }
    }

    private func resolvedSnapshot() -> SharedCalendarSnapshot? {
        guard isCancelled == false,
              let eventDocuments,
              let pillCycleDocuments else {
            return nil
        }

        if let publication {
            return resolvedVersionedSnapshot(
                publication: publication,
                eventDocuments: eventDocuments,
                pillCycleDocuments: pillCycleDocuments
            )
        }

        let legacyEvents = mappedEvents(
            from: eventDocuments.filter {
                FirestoreCalendarSharingMapper.publicationVersion(
                    in: $0.value
                ) == nil
            }
        )
        let legacyPillCycles = mappedPillCycles(
            from: pillCycleDocuments.filter {
                FirestoreCalendarSharingMapper.publicationVersion(
                    in: $0.value
                ) == nil
            }
        )
        return SharedCalendarSnapshot(
            events: legacyEvents,
            pillCycles: legacyPillCycles,
            computationSettings: legacyComputationSettings
        )
    }

    private func resolvedVersionedSnapshot(
        publication: FirestoreSharedCalendarPublicationMetadata,
        eventDocuments: [String: [String: Any]],
        pillCycleDocuments: [String: [String: Any]]
    ) -> SharedCalendarSnapshot? {
        let versionedEventDocuments = eventDocuments.filter {
            FirestoreCalendarSharingMapper.publicationVersion(in: $0.value)
                == publication.version
        }
        let versionedPillCycleDocuments = pillCycleDocuments.filter {
            FirestoreCalendarSharingMapper.publicationVersion(in: $0.value)
                == publication.version
        }
        guard versionedEventDocuments.count == publication.eventCount,
              versionedPillCycleDocuments.count
                == publication.pillCycleCount else {
            return nil
        }

        let events = mappedEvents(from: versionedEventDocuments)
        let pillCycles = mappedPillCycles(
            from: versionedPillCycleDocuments
        )
        guard events.count == publication.eventCount,
              pillCycles.count == publication.pillCycleCount else {
            return nil
        }
        return SharedCalendarSnapshot(
            events: events,
            pillCycles: pillCycles,
            computationSettings: publication.computationSettings,
            publicationVersion: publication.version
        )
    }

    private func mappedEvents(
        from documents: [String: [String: Any]]
    ) -> [SharedCalendarEvent] {
        documents.compactMap { id, data in
            FirestoreCalendarSharingMapper.sharedEvent(id: id, data: data)
        }
        .sorted {
            if $0.day == $1.day {
                return $0.type.rawValue < $1.type.rawValue
            }
            return $0.day < $1.day
        }
    }

    private func mappedPillCycles(
        from documents: [String: [String: Any]]
    ) -> [SharedPillCycleMetadata] {
        documents.compactMap { id, data in
            FirestoreCalendarSharingMapper.sharedPillCycle(
                id: id,
                data: data
            )
        }
        .sorted { $0.startDay < $1.startDay }
    }
}
