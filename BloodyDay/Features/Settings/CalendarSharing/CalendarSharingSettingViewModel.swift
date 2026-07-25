//
//  CalendarSharingSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class CalendarSharingSettingViewModel {
    private let authenticationService: AuthenticationService
    private var currentNonce: String?

    private(set) var user: AuthenticatedUser?
    private(set) var isSigningIn = false
    var errorMessage: String?

    init(authenticationService: AuthenticationService) {
        self.authenticationService = authenticationService
        self.user = authenticationService.currentUser
    }

    var isAuthenticated: Bool {
        user != nil
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.make()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            currentNonce = nil
            errorMessage = error.localizedDescription
        }
    }

    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>
    ) async {
        switch result {
        case .success(let authorization):
            await signIn(with: authorization)
        case .failure(let error):
            currentNonce = nil
            guard isCancellation(error) == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try authenticationService.signOut()
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func signIn(with authorization: ASAuthorization) async {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let rawNonce = currentNonce else {
            currentNonce = nil
            errorMessage = "Apple 로그인 정보를 확인하지 못했어요. 다시 시도해주세요."
            return
        }

        isSigningIn = true
        defer {
            isSigningIn = false
            currentNonce = nil
        }

        do {
            let credential = AppleAuthenticationCredential(
                identityToken: identityToken,
                rawNonce: rawNonce,
                fullName: appleCredential.fullName
            )
            user = try await authenticationService.signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else {
            return false
        }
        return authorizationError.code == .canceled
    }
}
