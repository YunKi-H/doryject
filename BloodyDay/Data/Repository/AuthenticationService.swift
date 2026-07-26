//
//  AuthenticationService.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import Foundation

struct AppleAuthenticationCredential {
    let identityToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
}

@MainActor
protocol AuthenticationService: AnyObject {
    var currentUser: AuthenticatedUser? { get }

    func signIn(with credential: AppleAuthenticationCredential) async throws -> AuthenticatedUser
    func signOut() throws
}
