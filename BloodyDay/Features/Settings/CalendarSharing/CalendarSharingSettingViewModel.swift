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
    private let sharedCalendarSyncScheduler: SharedCalendarSyncScheduling?
    private let sharedEventRepository: SharedCalendarEventRepository?
    private let calendarDisplayUpdater: CalendarDisplayEventUpdating?
    private let widgetSharingStateStore: WidgetCalendarSharingStateStore
    private var currentNonce: String?
    private var connectionObservation: CalendarConnectionObservation?
    private var requestObservation: CalendarConnectionObservation?
    private var sharedEventObservation: CalendarConnectionObservation?
    private var observedSharedConnectionID: String?

    private(set) var user: AuthenticatedUser?
    private(set) var profile: CalendarSharingProfile?
    private(set) var activeConnection: CalendarConnection?
    private(set) var incomingRequests: [CalendarConnectionRequest] = []
    private(set) var isSigningIn = false
    private(set) var isLoadingSharingState = false
    private(set) var isSendingRequest = false
    private(set) var isDisconnecting = false
    private(set) var statusMessage: String?
    var partnerConnectionCode = ""
    var errorMessage: String?

    init(
        authenticationService: AuthenticationService,
        connectionRepository: CalendarConnectionRepository,
        sharedCalendarSyncScheduler: SharedCalendarSyncScheduling? = nil,
        sharedEventRepository: SharedCalendarEventRepository? = nil,
        calendarDisplayUpdater: CalendarDisplayEventUpdating? = nil,
        widgetSharingStateStore: WidgetCalendarSharingStateStore = .init()
    ) {
        self.authenticationService = authenticationService
        self.connectionRepository = connectionRepository
        self.sharedCalendarSyncScheduler = sharedCalendarSyncScheduler
        self.sharedEventRepository = sharedEventRepository
        self.calendarDisplayUpdater = calendarDisplayUpdater
        self.widgetSharingStateStore = widgetSharingStateStore
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
            stopObservingSharingState()
            user = nil
            clearSharingState(clearDisplayedCalendar: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func refreshSharingState() async {
        if user == nil {
            user = authenticationService.currentUser
        }
        guard let user else {
            clearSharingState(clearDisplayedCalendar: false)
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
            updateDisplayedCalendar(for: activeConnection, userID: user.id)
            startObservingSharingState(for: user.id)
            sharedCalendarSyncScheduler?.schedule()
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
            updateDisplayedCalendar(
                for: activeConnection,
                userID: profile.userID
            )
            sharedCalendarSyncScheduler?.schedule()
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
                createdAt: connection.createdAt,
                computationSettings: connection.computationSettings
            )
            sharedCalendarSyncScheduler?.schedule()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectActiveConnection() async {
        guard let user,
              let connection = activeConnection else {
            return
        }

        isDisconnecting = true
        defer { isDisconnecting = false }
        do {
            try await connectionRepository.disconnect(
                connection,
                requestedBy: user.id
            )
            activeConnection = nil
            stopObservingSharedEvents()
            widgetSharingStateStore.clear()
            calendarDisplayUpdater?.displayLocalCalendar()
            statusMessage = connection.ownerID == user.id
                ? "캘린더 공유를 중단했어요."
                : "공유 캘린더 연결에서 나갔어요."
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

    private func clearSharingState(clearDisplayedCalendar: Bool) {
        stopObservingSharedEvents()
        if clearDisplayedCalendar {
            calendarDisplayUpdater?.displayLocalCalendar()
        }
        profile = nil
        activeConnection = nil
        incomingRequests = []
        partnerConnectionCode = ""
        statusMessage = nil
        widgetSharingStateStore.clear()
    }

    private func startObservingSharingState(for userID: String) {
        stopObservingSharingState()

        connectionObservation = connectionRepository.observeActiveConnection(
            for: userID
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let connection):
                    self.activeConnection = connection
                    self.updateDisplayedCalendar(
                        for: connection,
                        userID: userID
                    )
                    self.sharedCalendarSyncScheduler?.schedule()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        requestObservation = connectionRepository.observeIncomingRequests(
            for: userID
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let requests):
                    self.incomingRequests = requests
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func stopObservingSharingState() {
        connectionObservation?.cancel()
        requestObservation?.cancel()
        connectionObservation = nil
        requestObservation = nil
    }

    private func updateDisplayedCalendar(
        for connection: CalendarConnection?,
        userID: String
    ) {
        guard let connection else {
            widgetSharingStateStore.clear()
            stopObservingSharedEvents()
            calendarDisplayUpdater?.displayLocalCalendar()
            return
        }

        if connection.ownerID == userID {
            widgetSharingStateStore.save(
                WidgetCalendarSharingState(
                    role: .owner,
                    connectionID: connection.id
                )
            )
            stopObservingSharedEvents()
            calendarDisplayUpdater?.displayLocalCalendar()
            return
        }

        widgetSharingStateStore.save(
            WidgetCalendarSharingState(
                role: .viewer,
                connectionID: connection.id
            )
        )
        guard connection.viewerID == userID,
              let sharedEventRepository else {
            stopObservingSharedEvents()
            calendarDisplayUpdater?.displayLocalCalendar()
            return
        }

        calendarDisplayUpdater?.prepareSharedCalendar(
            connectionID: connection.id,
            computationSettings: connection.computationSettings
        )
        guard observedSharedConnectionID != connection.id else { return }
        stopObservingSharedEvents()
        observedSharedConnectionID = connection.id

        sharedEventObservation = sharedEventRepository.observeSnapshot(
            connectionID: connection.id
        ) { [weak self] result in
            Task { @MainActor in
                guard let self,
                      self.observedSharedConnectionID == connection.id else {
                    return
                }
                switch result {
                case .success(let snapshot):
                    self.calendarDisplayUpdater?
                        .displaySharedCalendar(snapshot: snapshot)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func stopObservingSharedEvents() {
        sharedEventObservation?.cancel()
        sharedEventObservation = nil
        observedSharedConnectionID = nil
    }
}
