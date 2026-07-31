//
//  WidgetSharedCalendarSyncService.swift
//  BloodyDayWidget
//
//  Created by Yunki on 7/26/26.
//

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
final class WidgetSharedCalendarSyncService {
    static let shared = WidgetSharedCalendarSyncService()

    private let stateStore = WidgetCalendarSharingStateStore()
    private let runtimeStore = CalendarSharingRuntimeStore()
    private let retryStore = SharedCalendarSyncRetryStore()

    private init() {}

    func synchronizeOwnedCalendarIfNeeded() async {
        retryStore.markPending()
        await performOwnerSynchronization()
    }

    func refreshForTimeline() async {
        guard let state = stateStore.load() else {
            retryStore.clear()
            return
        }
        switch state.role {
        case .owner:
            guard retryStore.shouldRetry() else { return }
            await performOwnerSynchronization()
        case .viewer:
            if retryStore.state == nil {
                retryStore.markPending()
            }
            await performViewerSynchronization(state: state)
        }
    }

    var nextRetryDate: Date? {
        retryStore.nextRetryDate
    }

    private func performOwnerSynchronization() async {
        guard let state = stateStore.load(),
              state.role == .owner else {
            retryStore.clear()
            return
        }

        do {
            try configureFirebaseIfNeeded()
            let auth = Auth.auth()
            try FirebaseAuthSharedAccess.configure(auth)
            guard let user = auth.currentUser else {
                throw WidgetSharedCalendarSyncError.unauthenticated
            }

            let database = Firestore.firestore()
            let document = try await database
                .collection(
                    FirestoreCalendarSharingMapper.Collection.connections
                )
                .document(state.connectionID)
                .getDocument()
            guard let data = document.data(),
                  data["ownerID"] as? String == user.uid,
                  data["status"] as? String != "terminating",
                  let connection =
                    FirestoreCalendarSharingMapper.connection(
                        id: document.documentID,
                        data: data
                    ) else {
                throw WidgetSharedCalendarSyncError
                    .ownedConnectionUnavailable
            }

            try await FirestoreSharedCalendarEventSyncService(
                database: database
            ).syncOwnedEvents(
                WidgetSharedEventStore.allEvents(),
                pillCycles: WidgetSharedEventStore.pillCycles(),
                connection: connection,
                computationSettings: SharedCalendarComputationSettings(
                    settings: loadSettings()
                )
            )
            retryStore.clear()
        } catch {
            retryStore.recordFailure()
            #if DEBUG
            print("[WidgetSharingSync] failed: \(error)")
            #endif
        }
    }

    private func performViewerSynchronization(
        state: WidgetCalendarSharingState
    ) async {
        do {
            try configureFirebaseIfNeeded()
            let auth = Auth.auth()
            try FirebaseAuthSharedAccess.configure(auth)
            guard let user = auth.currentUser else {
                clearViewerState()
                return
            }

            let database = Firestore.firestore()
            let connectionReference = database
                .collection(
                    FirestoreCalendarSharingMapper.Collection.connections
                )
                .document(state.connectionID)
            let connectionDocument = try await connectionReference
                .getDocument(source: .server)
            guard let connectionData = connectionDocument.data(),
                  connectionData["viewerID"] as? String == user.uid,
                  connectionData["status"] as? String != "terminating" else {
                clearViewerState()
                return
            }

            let publication = FirestoreCalendarSharingMapper
                .publicationMetadata(connectionData)
            let eventDocuments = try await documents(
                in: connectionReference.collection(
                    FirestoreCalendarSharingMapper.Collection.events
                ),
                publicationVersion: publication?.version
            )
            let pillCycleDocuments = try await documents(
                in: connectionReference.collection(
                    FirestoreCalendarSharingMapper.Collection.pillCycles
                ),
                publicationVersion: publication?.version
            )
            let snapshot = try makeViewerSnapshot(
                eventDocuments: eventDocuments,
                pillCycleDocuments: pillCycleDocuments,
                connectionData: connectionData,
                publication: publication
            )
            runtimeStore.save(
                CalendarSharingRuntimeState(
                    viewerConnectionID: state.connectionID,
                    events: snapshot.events.map(
                        CachedSharedCalendarEvent.init
                    ),
                    pillCycles: snapshot.pillCycles.map(
                        CachedSharedPillCycleMetadata.init
                    ),
                    computationSettings: snapshot.computationSettings,
                    publicationVersion: snapshot.publicationVersion
                )
            )
            retryStore.clear()
        } catch {
            if isPermissionDenied(error) {
                clearViewerState()
                return
            }
            retryStore.recordFailure()
            #if DEBUG
            print("[WidgetSharingRefresh] failed: \(error)")
            #endif
        }
    }

    private func documents(
        in collection: CollectionReference,
        publicationVersion: String?
    ) async throws -> [QueryDocumentSnapshot] {
        if let publicationVersion {
            return try await collection
                .whereField(
                    "publicationVersion",
                    isEqualTo: publicationVersion
                )
                .getDocuments(source: .server)
                .documents
        }
        return try await collection
            .getDocuments(source: .server)
            .documents
            .filter {
                FirestoreCalendarSharingMapper.publicationVersion(
                    in: $0.data()
                ) == nil
            }
    }

    private func makeViewerSnapshot(
        eventDocuments: [QueryDocumentSnapshot],
        pillCycleDocuments: [QueryDocumentSnapshot],
        connectionData: [String: Any],
        publication: FirestoreSharedCalendarPublicationMetadata?
    ) throws -> SharedCalendarSnapshot {
        if let publication {
            guard eventDocuments.count == publication.eventCount,
                  pillCycleDocuments.count
                    == publication.pillCycleCount else {
                throw WidgetSharedCalendarSyncError
                    .incompletePublication
            }
        }
        let events = eventDocuments.compactMap {
            FirestoreCalendarSharingMapper.sharedEvent(
                id: $0.documentID,
                data: $0.data()
            )
        }
        let pillCycles = pillCycleDocuments.compactMap {
            FirestoreCalendarSharingMapper.sharedPillCycle(
                id: $0.documentID,
                data: $0.data()
            )
        }
        if let publication {
            guard events.count == publication.eventCount,
                  pillCycles.count == publication.pillCycleCount else {
                throw WidgetSharedCalendarSyncError
                    .incompletePublication
            }
        }
        return SharedCalendarSnapshot(
            events: events,
            pillCycles: pillCycles,
            computationSettings: publication?.computationSettings
                ?? FirestoreCalendarSharingMapper
                    .computationSettings(connectionData),
            publicationVersion: publication?.version
        )
    }

    private func clearViewerState() {
        runtimeStore.clear()
        stateStore.clear()
        retryStore.clear()
    }

    private func isPermissionDenied(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == FirestoreErrorDomain
            && error.code
                == FirestoreErrorCode.Code.permissionDenied.rawValue
    }

    private func configureFirebaseIfNeeded() throws {
        guard FirebaseApp.app() == nil else { return }
        guard let path = Bundle.main.path(
            forResource: "GoogleService-Info",
            ofType: "plist"
        ),
        let options = FirebaseOptions(contentsOfFile: path) else {
            throw WidgetSharedCalendarSyncError.configurationMissing
        }
        FirebaseApp.configure(options: options)
    }

    private func loadSettings() -> UserSettings {
        guard let defaults = UserDefaults(
            suiteName: WidgetSnapshotStore.appGroupIdentifier
        ),
        let data = defaults.data(forKey: "user.settings.v1"),
        let settings = try? JSONDecoder().decode(
            UserSettings.self,
            from: data
        ) else {
            return .init()
        }
        return settings
    }
}

private enum WidgetSharedCalendarSyncError: LocalizedError {
    case configurationMissing
    case unauthenticated
    case ownedConnectionUnavailable
    case incompletePublication

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "위젯 Firebase 설정 파일을 찾지 못했어요."
        case .unauthenticated:
            return "위젯에서 공유 계정 인증 정보를 찾지 못했어요."
        case .ownedConnectionUnavailable:
            return "공유 중인 소유자 캘린더를 찾지 못했어요."
        case .incompletePublication:
            return "공유 캘린더의 최신 데이터가 아직 모두 도착하지 않았어요."
        }
    }
}
