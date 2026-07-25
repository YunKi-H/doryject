//
//  FirestoreCalendarConnectionRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreCalendarConnectionRepository: CalendarConnectionRepository {
    private let database: Firestore
    private let codeGenerator: () -> String

    init(
        database: Firestore = .firestore(),
        codeGenerator: @escaping () -> String = CalendarConnectionCodeGenerator.make
    ) {
        self.database = database
        self.codeGenerator = codeGenerator
    }

    func ensureProfile(for user: AuthenticatedUser) async throws -> CalendarSharingProfile {
        let userReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.users)
            .document(user.id)
        let existingSnapshot = try await userReference.getDocument()
        if let data = existingSnapshot.data(),
           let profile = FirestoreCalendarSharingMapper.profile(userID: user.id, data: data) {
            return profile
        }

        let displayName = normalizedDisplayName(for: user)
        for _ in 0..<5 {
            let code = codeGenerator()
            do {
                let value = try await createProfileIfNeeded(
                    userID: user.id,
                    displayName: displayName,
                    proposedCode: code
                )
                guard let resolvedCode = value as? String else {
                    throw CalendarConnectionRepositoryError.invalidServerResponse
                }
                return CalendarSharingProfile(
                    userID: user.id,
                    displayName: displayName,
                    connectionCode: resolvedCode
                )
            } catch {
                let nsError = error as NSError
                if nsError.domain == Self.transactionErrorDomain,
                   nsError.code == Self.connectionCodeCollisionErrorCode {
                    continue
                }
                throw error
            }
        }

        throw CalendarConnectionRepositoryError.connectionCodeGenerationFailed
    }

    func activeConnection(for userID: String) async throws -> CalendarConnection? {
        let membershipSnapshot = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(userID)
            .getDocument()
        guard let connectionID = membershipSnapshot.data()?["connectionID"] as? String else {
            return nil
        }
        let document = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connectionID)
            .getDocument()
        guard let data = document.data() else { return nil }
        return FirestoreCalendarSharingMapper.connection(
            id: document.documentID,
            data: data
        )
    }

    func incomingRequests(for userID: String) async throws -> [CalendarConnectionRequest] {
        let snapshot = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .whereField("recipientID", isEqualTo: userID)
            .getDocuments()

        return snapshot.documents
            .compactMap {
                FirestoreCalendarSharingMapper.request(
                    id: $0.documentID,
                    data: $0.data()
                )
            }
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func sendRequest(
        from profile: CalendarSharingProfile,
        to connectionCode: String
    ) async throws {
        let normalizedCode = CalendarConnectionCodeGenerator.normalize(connectionCode)
        guard normalizedCode.count == 8 else {
            throw CalendarConnectionRepositoryError.invalidConnectionCode
        }

        let codeSnapshot = try await database
            .collection(FirestoreCalendarSharingMapper.Collection.connectionCodes)
            .document(normalizedCode)
            .getDocument()
        guard let recipientID = codeSnapshot.data()?["userID"] as? String else {
            throw CalendarConnectionRepositoryError.connectionCodeNotFound
        }
        guard recipientID != profile.userID else {
            throw CalendarConnectionRepositoryError.cannotConnectToSelf
        }

        let requestID = Self.pairIdentifier(profile.userID, recipientID)
        try await database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(requestID)
            .setData([
                "senderID": profile.userID,
                "senderDisplayName": profile.displayName,
                "recipientID": recipientID,
                "status": CalendarConnectionRequestStatus.pending.rawValue,
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    func accept(
        _ request: CalendarConnectionRequest,
        recipient: CalendarSharingProfile,
        ownerID: String
    ) async throws -> CalendarConnection {
        guard request.recipientID == recipient.userID else {
            throw CalendarConnectionRepositoryError.requestRecipientMismatch
        }
        guard ownerID == request.senderID || ownerID == recipient.userID else {
            throw CalendarConnectionRepositoryError.invalidOwner
        }

        let ownerIsRecipient = ownerID == recipient.userID
        let ownerDisplayName = ownerIsRecipient
            ? recipient.displayName
            : request.senderDisplayName
        let viewerID = ownerIsRecipient ? request.senderID : recipient.userID
        let viewerDisplayName = ownerIsRecipient
            ? request.senderDisplayName
            : recipient.displayName
        let requestReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(request.id)
        let connectionReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(request.id)
        let senderMembershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(request.senderID)
        let recipientMembershipReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.memberships)
            .document(recipient.userID)

        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(requestReference)
                let senderMembership = try transaction.getDocument(senderMembershipReference)
                let recipientMembership = try transaction.getDocument(recipientMembershipReference)
                guard let data = snapshot.data(),
                      data["recipientID"] as? String == recipient.userID,
                      data["status"] as? String == CalendarConnectionRequestStatus.pending.rawValue else {
                    throw CalendarConnectionRepositoryError.requestUnavailable
                }
                guard senderMembership.exists == false,
                      recipientMembership.exists == false else {
                    throw CalendarConnectionRepositoryError.alreadyConnected
                }

                transaction.updateData(
                    ["status": CalendarConnectionRequestStatus.accepted.rawValue],
                    forDocument: requestReference
                )
                transaction.setData([
                    "ownerID": ownerID,
                    "ownerDisplayName": ownerDisplayName,
                    "viewerID": viewerID,
                    "viewerDisplayName": viewerDisplayName,
                    "participantIDs": [ownerID, viewerID],
                    "sharedPeriod": true,
                    "sharedPill": true,
                    "sharedLove": true,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: connectionReference)
                let membershipData: [String: Any] = [
                    "connectionID": request.id,
                    "participantIDs": [request.senderID, recipient.userID],
                    "createdAt": FieldValue.serverTimestamp()
                ]
                var senderMembershipData = membershipData
                senderMembershipData["userID"] = request.senderID
                var recipientMembershipData = membershipData
                recipientMembershipData["userID"] = recipient.userID
                transaction.setData(
                    senderMembershipData,
                    forDocument: senderMembershipReference
                )
                transaction.setData(
                    recipientMembershipData,
                    forDocument: recipientMembershipReference
                )
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        return CalendarConnection(
            id: request.id,
            ownerID: ownerID,
            ownerDisplayName: ownerDisplayName,
            viewerID: viewerID,
            viewerDisplayName: viewerDisplayName,
            sharedEventTypes: SharedEventTypeSelection(),
            createdAt: .now
        )
    }

    func decline(
        _ request: CalendarConnectionRequest,
        recipientID: String
    ) async throws {
        guard request.recipientID == recipientID else {
            throw CalendarConnectionRepositoryError.requestRecipientMismatch
        }
        try await database
            .collection(FirestoreCalendarSharingMapper.Collection.requests)
            .document(request.id)
            .updateData([
                "status": CalendarConnectionRequestStatus.declined.rawValue
            ])
    }

    func updateSharedEventTypes(
        connectionID: String,
        ownerID: String,
        selection: SharedEventTypeSelection
    ) async throws {
        try await database
            .collection(FirestoreCalendarSharingMapper.Collection.connections)
            .document(connectionID)
            .updateData([
                "sharedPeriod": selection.period,
                "sharedPill": selection.pill,
                "sharedLove": selection.love,
                "sharingUpdatedAt": FieldValue.serverTimestamp(),
                "sharingUpdatedBy": ownerID
            ])
    }

    private func createProfileIfNeeded(
        userID: String,
        displayName: String,
        proposedCode: String
    ) async throws -> Any? {
        let userReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.users)
            .document(userID)
        let codeReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.connectionCodes)
            .document(proposedCode)

        return try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let userSnapshot = try transaction.getDocument(userReference)
                let codeSnapshot = try transaction.getDocument(codeReference)

                if let existingCode = userSnapshot.data()?["connectionCode"] as? String {
                    return existingCode
                }
                guard codeSnapshot.exists == false else {
                    errorPointer?.pointee = NSError(
                        domain: Self.transactionErrorDomain,
                        code: Self.connectionCodeCollisionErrorCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Connection code collision"
                        ]
                    )
                    return nil
                }

                transaction.setData([
                    "displayName": displayName,
                    "connectionCode": proposedCode,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: userReference)
                transaction.setData([
                    "userID": userID
                ], forDocument: codeReference)
                return proposedCode
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func normalizedDisplayName(for user: AuthenticatedUser) -> String {
        let trimmedName = user.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedName, trimmedName.isEmpty == false else {
            return "B-Day 사용자"
        }
        return trimmedName
    }

    private static func pairIdentifier(_ firstUserID: String, _ secondUserID: String) -> String {
        [firstUserID, secondUserID]
            .sorted()
            .joined(separator: "_")
    }

    private static let transactionErrorDomain = "BloodyDay.CalendarConnectionTransaction"
    private static let connectionCodeCollisionErrorCode = 1
}

private enum CalendarConnectionCodeGenerator {
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func make() -> String {
        String((0..<8).compactMap { _ in characters.randomElement() })
    }

    static func normalize(_ code: String) -> String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { characters.contains($0) }
    }
}

enum CalendarConnectionRepositoryError: LocalizedError {
    case invalidServerResponse
    case connectionCodeCollision
    case connectionCodeGenerationFailed
    case invalidConnectionCode
    case connectionCodeNotFound
    case cannotConnectToSelf
    case requestRecipientMismatch
    case requestUnavailable
    case invalidOwner
    case alreadyConnected

    var errorDescription: String? {
        switch self {
        case .invalidServerResponse:
            return "서버에서 연결 정보를 확인하지 못했어요."
        case .connectionCodeCollision, .connectionCodeGenerationFailed:
            return "연결 ID를 만들지 못했어요. 잠시 후 다시 시도해주세요."
        case .invalidConnectionCode:
            return "상대방의 연결 ID를 입력해주세요."
        case .connectionCodeNotFound:
            return "일치하는 연결 ID를 찾지 못했어요."
        case .cannotConnectToSelf:
            return "내 연결 ID로는 요청할 수 없어요."
        case .requestRecipientMismatch:
            return "이 연결 요청을 처리할 권한이 없어요."
        case .requestUnavailable:
            return "이미 처리됐거나 취소된 연결 요청이에요."
        case .invalidOwner:
            return "사용할 캘린더를 확인하지 못했어요."
        case .alreadyConnected:
            return "두 사람 중 한 명이 이미 다른 캘린더와 연결되어 있어요."
        }
    }
}
