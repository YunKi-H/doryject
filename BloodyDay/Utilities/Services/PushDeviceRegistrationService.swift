//
//  PushDeviceRegistrationService.swift
//  BloodyDay
//
//  Created by Yunki on 8/2/26.
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseInstallations
import FirebaseMessaging
import Foundation

@MainActor
protocol PushDeviceRegistering: AnyObject {
    func refreshRegistration() async
    func unregisterCurrentDevice() async throws
}

@MainActor
final class PushDeviceRegistrationService: PushDeviceRegistering {
    static let shared = PushDeviceRegistrationService()

    private enum Key {
        static let installationID = "pushDevice.installationID"
        static let fcmToken = "pushDevice.fcmToken"
        static let synchronizedFingerprint =
            "pushDevice.synchronizedFingerprint"
    }

    private let auth: Auth
    private let firestore: Firestore
    private let defaults: UserDefaults
    private var synchronizingFingerprints: Set<String> = []

    init(
        auth: Auth = .auth(),
        firestore: Firestore = .firestore(),
        defaults: UserDefaults = .standard
    ) {
        self.auth = auth
        self.firestore = firestore
        self.defaults = defaults
    }

    func updateFCMToken(_ fcmToken: String) async {
        defaults.set(fcmToken, forKey: Key.fcmToken)
        await refreshInstallationIDAndSynchronize()
    }

    func refreshRegistration() async {
        do {
            let installationID = try await fetchInstallationID()
            let fcmToken = try await fetchFCMToken()
            defaults.set(installationID, forKey: Key.installationID)
            defaults.set(fcmToken, forKey: Key.fcmToken)
            await synchronizeIfAuthenticated()
        } catch {
            #if DEBUG
            print(
                "[PushDeviceRegistration] identifier refresh failed: "
                    + error.localizedDescription
            )
            #endif
        }
    }

    func synchronizeIfAuthenticated() async {
        await FirebaseAuthSharedAccess.waitForMigration()
        guard let userID = auth.currentUser?.uid,
              let installationID = storedInstallationID,
              let fcmToken = storedFCMToken else {
            #if DEBUG
            print(
                "[PushDeviceRegistration] waiting for values "
                    + "auth=\(auth.currentUser != nil) "
                    + "installationID=\(storedInstallationID != nil) "
                    + "fcmToken=\(storedFCMToken != nil)"
            )
            #endif
            return
        }

        let fingerprint = registrationFingerprint(
            userID: userID,
            installationID: installationID,
            fcmToken: fcmToken
        )
        guard defaults.string(forKey: Key.synchronizedFingerprint)
                != fingerprint,
              synchronizingFingerprints.contains(fingerprint) == false else {
            return
        }
        synchronizingFingerprints.insert(fingerprint)
        defer { synchronizingFingerprints.remove(fingerprint) }

        do {
            try await deviceDocument(
                userID: userID,
                installationID: installationID
            ).setData(
                [
                    "installationID": installationID,
                    "fcmToken": fcmToken,
                    "platform": "ios",
                    "appVersion": appVersion,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
            defaults.set(fingerprint, forKey: Key.synchronizedFingerprint)
            #if DEBUG
            print("[PushDeviceRegistration] device document saved")
            #endif
        } catch {
            #if DEBUG
            print(
                "[PushDeviceRegistration] registration failed: "
                    + error.localizedDescription
            )
            #endif
        }
    }

    func unregisterCurrentDevice() async throws {
        await FirebaseAuthSharedAccess.waitForMigration()
        guard let userID = auth.currentUser?.uid,
              let installationID = storedInstallationID else {
            return
        }

        try await deviceDocument(
            userID: userID,
            installationID: installationID
        ).delete()
        defaults.removeObject(forKey: Key.synchronizedFingerprint)
    }

    private var storedInstallationID: String? {
        defaults.string(forKey: Key.installationID)
    }

    private var storedFCMToken: String? {
        defaults.string(forKey: Key.fcmToken)
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
    }

    private func registrationFingerprint(
        userID: String,
        installationID: String,
        fcmToken: String
    ) -> String {
        [userID, installationID, fcmToken, appVersion]
            .joined(separator: "|")
    }

    private func refreshInstallationIDAndSynchronize() async {
        do {
            let installationID = try await fetchInstallationID()
            defaults.set(installationID, forKey: Key.installationID)
            await synchronizeIfAuthenticated()
        } catch {
            #if DEBUG
            print(
                "[PushDeviceRegistration] FID refresh failed: "
                    + error.localizedDescription
            )
            #endif
        }
    }

    private func fetchInstallationID() async throws -> String {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String, Error>) in
            Installations.installations().installationID { identifier, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let identifier {
                    continuation.resume(returning: identifier)
                } else {
                    continuation.resume(
                        throwing: PushDeviceRegistrationError
                            .missingInstallationID
                    )
                }
            }
        }
    }

    private func fetchFCMToken() async throws -> String {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String, Error>) in
            Messaging.messaging().token { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(
                        throwing: PushDeviceRegistrationError.missingFCMToken
                    )
                }
            }
        }
    }

    private func deviceDocument(
        userID: String,
        installationID: String
    ) -> DocumentReference {
        firestore.collection("users")
            .document(userID)
            .collection("devices")
            .document(installationID)
    }
}

private enum PushDeviceRegistrationError: LocalizedError {
    case missingInstallationID
    case missingFCMToken

    var errorDescription: String? {
        switch self {
        case .missingInstallationID:
            return "Firebase Installation ID를 받지 못했어요."
        case .missingFCMToken:
            return "FCM 토큰을 받지 못했어요."
        }
    }
}
