//
//  AppleSignInNonce.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import CryptoKit
import Foundation
import Security

enum AppleSignInNonce {
    static func make(length: Int = 32) throws -> String {
        precondition(length > 0)

        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AppleSignInNonceError.generationFailed(status)
        }

        let characters = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private enum AppleSignInNonceError: LocalizedError {
    case generationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "로그인 요청을 안전하게 생성하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}
