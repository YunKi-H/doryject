//
//  AuthenticatedUser.swift
//  BloodyDay
//
//  Created by Yunki on 7/25/26.
//

import Foundation

struct AuthenticatedUser: Equatable, Sendable {
    let id: String
    let displayName: String?
    let email: String?
}
