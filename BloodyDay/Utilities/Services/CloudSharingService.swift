//
//  CloudSharingService.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import CloudKit
import Foundation

enum CloudSharingAvailability: Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

protocol CloudSharingService {
    func fetchAvailability() async -> CloudSharingAvailability
    func accept(_ metadata: CKShare.Metadata) async throws
}

enum CloudSharingError: Error {
    case missingContainer
}

final class CloudKitSharingService: CloudSharingService {
    static let acceptedShareNotification = Notification.Name("CloudKitSharingService.acceptedShare")
    static let containerIdentifier = "iCloud.dorypawn.BDay"
    
    private let container: CKContainer
    
    init(containerIdentifier: String = CloudKitSharingService.containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
    }
    
    func fetchAvailability() async -> CloudSharingAvailability {
        do {
            let status = try await accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            case .couldNotDetermine:
                return .couldNotDetermine
            @unknown default:
                return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }
    
    func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.accept(metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                NotificationCenter.default.post(
                    name: Self.acceptedShareNotification,
                    object: nil,
                    userInfo: ["metadata": metadata]
                )
                continuation.resume(returning: ())
            }
        }
    }
    
    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }
}
