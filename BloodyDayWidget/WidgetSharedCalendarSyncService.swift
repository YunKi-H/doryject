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

    private init() {}

    func synchronizeOwnedCalendarIfNeeded() async {
        guard let state = stateStore.load(),
              state.role == .owner else {
            stateStore.setPendingSync(false)
            return
        }

        stateStore.setPendingSync(true)
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
            stateStore.setPendingSync(false)
        } catch {
            #if DEBUG
            print("[WidgetSharingSync] failed: \(error)")
            #endif
        }
    }

    func retryPendingSyncIfNeeded() async {
        guard stateStore.hasPendingSync else { return }
        await synchronizeOwnedCalendarIfNeeded()
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

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "위젯 Firebase 설정 파일을 찾지 못했어요."
        case .unauthenticated:
            return "위젯에서 공유 계정 인증 정보를 찾지 못했어요."
        case .ownedConnectionUnavailable:
            return "공유 중인 소유자 캘린더를 찾지 못했어요."
        }
    }
}
