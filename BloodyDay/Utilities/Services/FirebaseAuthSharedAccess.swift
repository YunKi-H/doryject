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
            }
        } catch {
            #if DEBUG
            print(
                "[FirebaseAuth] shared keychain configuration failed: "
                + error.localizedDescription
            )
            #endif
        }
    }
}
