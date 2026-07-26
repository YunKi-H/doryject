//
//  PreviewAuthenticationService.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

@MainActor
final class PreviewAuthenticationService: AuthenticationService {
    var currentUser: AuthenticatedUser?

    init(currentUser: AuthenticatedUser? = nil) {
        self.currentUser = currentUser
    }

    func signIn(
        with credential: AppleAuthenticationCredential
    ) async throws -> AuthenticatedUser {
        let user = AuthenticatedUser(
            id: "preview-user",
            displayName: "B-Day 사용자",
            email: nil
        )
        currentUser = user
        return user
    }

    func signOut() throws {
        currentUser = nil
    }
}
