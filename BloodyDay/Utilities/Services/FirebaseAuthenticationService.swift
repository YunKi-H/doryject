//
//  FirebaseAuthenticationService.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import FirebaseAuth
import Foundation

@MainActor
final class FirebaseAuthenticationService: AuthenticationService {
    private let auth: Auth

    init(auth: Auth = .auth()) {
        self.auth = auth
    }

    var currentUser: AuthenticatedUser? {
        auth.currentUser.map(Self.makeAuthenticatedUser)
    }

    func resolvedCurrentUser() async -> AuthenticatedUser? {
        await FirebaseAuthSharedAccess.waitForMigration()
        return currentUser
    }

    func signIn(
        with credential: AppleAuthenticationCredential
    ) async throws -> AuthenticatedUser {
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: credential.identityToken,
            rawNonce: credential.rawNonce,
            fullName: credential.fullName
        )
        let result = try await auth.signIn(with: firebaseCredential)
        return Self.makeAuthenticatedUser(from: result.user)
    }

    func signOut() throws {
        try auth.signOut()
    }

    private static func makeAuthenticatedUser(from user: User) -> AuthenticatedUser {
        AuthenticatedUser(
            id: user.uid,
            displayName: user.displayName,
            email: user.email
        )
    }
}
