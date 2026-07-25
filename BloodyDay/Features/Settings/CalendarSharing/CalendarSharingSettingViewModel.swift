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
    private let connectionRepository: CalendarConnectionRepository
    private var currentNonce: String?

    private(set) var user: AuthenticatedUser?
    private(set) var profile: CalendarSharingProfile?
    private(set) var activeConnection: CalendarConnection?
    private(set) var incomingRequests: [CalendarConnectionRequest] = []
    private(set) var isSigningIn = false
    private(set) var isLoadingSharingState = false
    private(set) var isSendingRequest = false
    private(set) var statusMessage: String?
    var partnerConnectionCode = ""
    var errorMessage: String?

    init(
        authenticationService: AuthenticationService,
        connectionRepository: CalendarConnectionRepository
    ) {
        self.authenticationService = authenticationService
        self.connectionRepository = connectionRepository
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
            clearSharingState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func refreshSharingState() async {
        guard let user else {
            clearSharingState()
            return
        }

        isLoadingSharingState = true
        defer { isLoadingSharingState = false }
        do {
            let profile = try await connectionRepository.ensureProfile(for: user)
            self.profile = profile
            async let connection = connectionRepository.activeConnection(for: user.id)
            async let requests = connectionRepository.incomingRequests(for: user.id)
            activeConnection = try await connection
            incomingRequests = try await requests
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendConnectionRequest() async {
        guard let profile else { return }
        isSendingRequest = true
        defer { isSendingRequest = false }
        do {
            try await connectionRepository.sendRequest(
                from: profile,
                to: partnerConnectionCode
            )
            partnerConnectionCode = ""
            statusMessage = "연결 요청을 보냈어요."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func accept(
        _ request: CalendarConnectionRequest,
        useMyCalendar: Bool
    ) async {
        guard let profile else { return }
        do {
            activeConnection = try await connectionRepository.accept(
                request,
                recipient: profile,
                ownerID: useMyCalendar ? profile.userID : request.senderID
            )
            incomingRequests.removeAll { $0.id == request.id }
            statusMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decline(_ request: CalendarConnectionRequest) async {
        guard let user else { return }
        do {
            try await connectionRepository.decline(
                request,
                recipientID: user.id
            )
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSharedEventType(_ type: EventType, enabled: Bool) async {
        guard let user,
              let connection = activeConnection,
              connection.ownerID == user.id else {
            return
        }

        var selection = connection.sharedEventTypes
        switch type {
        case .period:
            selection.period = enabled
        case .pill:
            selection.pill = enabled
        case .love:
            selection.love = enabled
        case .ovulation, .fertile, .delayed:
            return
        }

        do {
            try await connectionRepository.updateSharedEventTypes(
                connectionID: connection.id,
                ownerID: user.id,
                selection: selection
            )
            activeConnection = CalendarConnection(
                id: connection.id,
                ownerID: connection.ownerID,
                ownerDisplayName: connection.ownerDisplayName,
                viewerID: connection.viewerID,
                viewerDisplayName: connection.viewerDisplayName,
                sharedEventTypes: selection,
                createdAt: connection.createdAt
            )
        } catch {
            errorMessage = error.localizedDescription
        }
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
            await refreshSharingState()
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

    private func clearSharingState() {
        profile = nil
        activeConnection = nil
        incomingRequests = []
        partnerConnectionCode = ""
        statusMessage = nil
    }
}
