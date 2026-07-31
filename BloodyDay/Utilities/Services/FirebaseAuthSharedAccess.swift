//
//  FirebaseAuthSharedAccess.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseAuth
import Foundation

enum FirebaseAuthSharedAccess {
    static let accessGroup =
        CalendarSharingRuntimeStore.appGroupIdentifier
    private static let migrationState = FirebaseAuthMigrationState()

    static func configure(_ auth: Auth = .auth()) throws {
        try auth.useUserAccessGroup(accessGroup)
    }

    static func configureAndMigrateCurrentUser(
        _ auth: Auth = .auth()
    ) {
        let previousUser = auth.currentUser
        do {
            let sharedUser = try auth.getStoredUser(
                forAccessGroup: accessGroup
            )
            try configure(auth)
            guard sharedUser == nil,
                  let previousUser else {
                completeMigration()
                return
            }
            auth.updateCurrentUser(previousUser) { error in
                #if DEBUG
                if let error {
                    print(
                        "[FirebaseAuth] shared keychain migration failed: "
                        + error.localizedDescription
                    )
                }
                #endif
                completeMigration()
            }
        } catch {
            #if DEBUG
            print(
                "[FirebaseAuth] shared keychain configuration failed: "
                + error.localizedDescription
            )
            #endif
            completeMigration()
        }
    }

    static func waitForMigration() async {
        await migrationState.waitForCompletion()
    }

    private static func completeMigration() {
        migrationState.complete()
    }
}

private final class FirebaseAuthMigrationState: @unchecked Sendable {
    private let lock = NSLock()
    private var isComplete = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func waitForCompletion() async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = lock.withLock {
                guard isComplete == false else { return true }
                waiters.append(continuation)
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    func complete() {
        let pendingWaiters: [CheckedContinuation<Void, Never>] = lock.withLock {
            guard isComplete == false else { return [] }
            isComplete = true
            let pendingWaiters = waiters
            waiters.removeAll()
            return pendingWaiters
        }
        pendingWaiters.forEach { $0.resume() }
    }
}
