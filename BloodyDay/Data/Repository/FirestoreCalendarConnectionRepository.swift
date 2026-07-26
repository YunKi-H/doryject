//
//  FirestoreCalendarConnectionRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreCalendarConnectionRepository:
    CalendarConnectionRepository
{
    private let profileStore: FirestoreCalendarProfileStore
    private let requestStore: FirestoreCalendarRequestStore
    private let connectionStore: FirestoreCalendarConnectionStore

    init(
        database: Firestore = .firestore(),
        codeGenerator: @escaping () -> String =
            CalendarConnectionCodeGenerator.make
    ) {
        profileStore = FirestoreCalendarProfileStore(
            database: database,
            codeGenerator: codeGenerator
        )
        requestStore = FirestoreCalendarRequestStore(
            database: database
        )
        connectionStore = FirestoreCalendarConnectionStore(
            database: database
        )
    }

    func ensureProfile(
        for user: AuthenticatedUser
    ) async throws -> CalendarSharingProfile {
        try await profileStore.ensureProfile(for: user)
    }

    func activeConnection(
        for userID: String
    ) async throws -> CalendarConnection? {
        try await connectionStore.activeConnection(for: userID)
    }

    func incomingRequests(
        for userID: String
    ) async throws -> [CalendarConnectionRequest] {
        try await requestStore.incomingRequests(for: userID)
    }

    func observeActiveConnection(
        for userID: String,
        onChange: @escaping (
            Result<CalendarConnection?, Error>
        ) -> Void
    ) -> CalendarConnectionObservation {
        connectionStore.observeActiveConnection(
            for: userID,
            onChange: onChange
        )
    }

    func observeIncomingRequests(
        for userID: String,
        onChange: @escaping (
            Result<[CalendarConnectionRequest], Error>
        ) -> Void
    ) -> CalendarConnectionObservation {
        requestStore.observeIncomingRequests(
            for: userID,
            onChange: onChange
        )
    }

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws {
        try await requestStore.sendRequest(
            from: profile,
            to: connectionCode
        )
    }

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection {
        try await connectionStore.accept(
            request,
            recipient: recipient,
            ownerID: ownerID
        )
    }

    func decline(
        _ request: CalendarConnectionRequest,
        recipientID: String
    ) async throws {
        try await requestStore.decline(
            request,
            recipientID: recipientID
        )
    }

    func updateSharedEventTypes(
        connectionID: String,
        ownerID: String,
        selection: SharedEventTypeSelection
    ) async throws {
        try await connectionStore.updateSharedEventTypes(
            connectionID: connectionID,
            ownerID: ownerID,
            selection: selection
        )
    }

    func disconnect(
        _ connection: CalendarConnection,
        requestedBy userID: String
    ) async throws {
        try await connectionStore.disconnect(
            connection,
            requestedBy: userID
        )
    }
}

enum CalendarConnectionRepositoryError: LocalizedError {
    case invalidServerResponse
    case connectionCodeGenerationFailed
    case invalidConnectionCode
    case connectionCodeNotFound
    case cannotConnectToSelf
    case requestRecipientMismatch
    case incomingRequestAlreadyExists
    case reverseRequestUnavailable
    case invalidOwner
    case alreadyConnected
    case cachedConnectionUnavailable
    case notConnectionParticipant

    var errorDescription: String? {
        switch self {
        case .invalidServerResponse:
            return "서버에서 연결 정보를 확인하지 못했어요."
        case .connectionCodeGenerationFailed:
            return "연결 ID를 만들지 못했어요. 잠시 후 다시 시도해주세요."
        case .invalidConnectionCode:
            return "상대방의 연결 ID를 입력해주세요."
        case .connectionCodeNotFound:
            return "일치하는 연결 ID를 찾지 못했어요."
        case .cannotConnectToSelf:
            return "내 연결 ID로는 요청할 수 없어요."
        case .requestRecipientMismatch:
            return "이 연결 요청을 처리할 권한이 없어요."
        case .incomingRequestAlreadyExists:
            return "상대방이 이미 연결 요청을 보냈어요. 받은 요청에서 수락해주세요."
        case .reverseRequestUnavailable:
            return "상대방이 보낸 이전 요청이 거절된 상태예요. 상대방에게 다시 요청해달라고 알려주세요."
        case .invalidOwner:
            return "사용할 캘린더를 확인하지 못했어요."
        case .alreadyConnected:
            return "두 사람 중 한 명이 이미 다른 캘린더와 연결되어 있어요."
        case .cachedConnectionUnavailable:
            return "오프라인 상태라 최신 연결 정보를 확인하지 못했어요."
        case .notConnectionParticipant:
            return "이 캘린더 연결을 해제할 권한이 없어요."
        }
    }
}
