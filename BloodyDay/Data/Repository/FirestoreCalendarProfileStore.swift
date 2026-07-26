//
//  FirestoreCalendarProfileStore.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

final class FirestoreCalendarProfileStore {
    private let database: Firestore
    private let codeGenerator: () -> String

    init(
        database: Firestore,
        codeGenerator: @escaping () -> String
    ) {
        self.database = database
        self.codeGenerator = codeGenerator
    }

    func ensureProfile(
        for user: AuthenticatedUser
    ) async throws -> CalendarSharingProfile {
        let userReference = database
            .collection(FirestoreCalendarSharingMapper.Collection.users)
            .document(user.id)
        let existingSnapshot = try await userReference.getDocument()
        if let data = existingSnapshot.data(),
           let profile = FirestoreCalendarSharingMapper.profile(
               userID: user.id,
               data: data
           ) {
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
                    throw CalendarConnectionRepositoryError
                        .invalidServerResponse
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

        throw CalendarConnectionRepositoryError
            .connectionCodeGenerationFailed
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
            .collection(
                FirestoreCalendarSharingMapper.Collection.connectionCodes
            )
            .document(proposedCode)

        return try await database.runTransaction {
            transaction,
            errorPointer -> Any? in
            do {
                let userSnapshot = try transaction.getDocument(
                    userReference
                )
                let codeSnapshot = try transaction.getDocument(
                    codeReference
                )

                if let existingCode =
                    userSnapshot.data()?["connectionCode"] as? String {
                    return existingCode
                }
                guard codeSnapshot.exists == false else {
                    errorPointer?.pointee = NSError(
                        domain: Self.transactionErrorDomain,
                        code: Self.connectionCodeCollisionErrorCode,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Connection code collision"
                        ]
                    )
                    return nil
                }

                transaction.setData(
                    FirestoreCalendarSharingMapper.profileData(
                        displayName: displayName,
                        connectionCode: proposedCode
                    ),
                    forDocument: userReference
                )
                transaction.setData(
                    FirestoreCalendarSharingMapper.connectionCodeData(
                        userID: userID
                    ),
                    forDocument: codeReference
                )
                return proposedCode
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func normalizedDisplayName(
        for user: AuthenticatedUser
    ) -> String {
        let trimmedName = user.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedName, trimmedName.isEmpty == false else {
            return "B-Day 사용자"
        }
        return trimmedName
    }

    private static let transactionErrorDomain =
        "BloodyDay.CalendarConnectionTransaction"
    private static let connectionCodeCollisionErrorCode = 1
}

enum CalendarConnectionCodeGenerator {
    private static let characters = Array(
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    )

    static func make() -> String {
        String(
            (0..<8).compactMap { _ in characters.randomElement() }
        )
    }

    static func normalize(_ code: String) -> String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { characters.contains($0) }
    }
}
