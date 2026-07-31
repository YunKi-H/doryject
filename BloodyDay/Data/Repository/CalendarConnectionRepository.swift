//
//  CalendarConnectionRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

final class CalendarConnectionObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void = {}) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

    deinit {
        cancel()
    }
}

protocol CalendarConnectionRepository {
    func ensureProfile(for user: AuthenticatedUser) async throws -> CalendarSharingProfile
    func activeConnection(for userID: String) async throws -> CalendarConnection?
    func incomingRequests(for userID: String) async throws -> [CalendarConnectionRequest]
    func observeActiveConnection(
        for userID: String,
        onChange: @escaping (Result<CalendarConnection?, Error>) -> Void
    ) -> CalendarConnectionObservation
    func observeIncomingRequests(
        for userID: String,
        onChange: @escaping (Result<[CalendarConnectionRequest], Error>) -> Void
    ) -> CalendarConnectionObservation

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection

    func decline(_ request: CalendarConnectionRequest, recipientID: String) async throws

    /// 이전 연결 해제가 중간에 멈춘 경우 남은 서버 문서를 정리한다.
    /// 정리할 작업이 있었으면 `true`를 반환한다.
    func resumePendingDisconnect(for userID: String) async throws -> Bool

    func disconnect(
        _ connection: CalendarConnection,
        requestedBy userID: String
    ) async throws
}
