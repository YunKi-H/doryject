//
//  SharedCalendar.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

struct SharedCalendar: Codable, Equatable, Hashable, Identifiable {
    let id: String
    var ownerDisplayName: String?
    var remoteTitle: String?
    var localDisplayName: String?
    var sharedEventTypes: SharedEventTypeSelection
    var permission: SharedCalendarPermission
    var acceptedAt: Date?
    var updatedAt: Date?
    
    init(
        id: String,
        ownerDisplayName: String? = nil,
        remoteTitle: String? = nil,
        localDisplayName: String? = nil,
        sharedEventTypes: SharedEventTypeSelection = .none,
        permission: SharedCalendarPermission = .readOnly,
        acceptedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.ownerDisplayName = ownerDisplayName
        self.remoteTitle = remoteTitle
        self.localDisplayName = localDisplayName
        self.sharedEventTypes = sharedEventTypes
        self.permission = permission
        self.acceptedAt = acceptedAt
        self.updatedAt = updatedAt
    }
    
    var displayName: String {
        if let localDisplayName = localDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           localDisplayName.isEmpty == false {
            return localDisplayName
        }
        
        if let remoteTitle = remoteTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           remoteTitle.isEmpty == false {
            return remoteTitle
        }
        
        if let ownerDisplayName = ownerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           ownerDisplayName.isEmpty == false {
            return "\(ownerDisplayName) 캘린더"
        }
        
        return "공유 캘린더"
    }
}

enum SharedCalendarPermission: String, Codable, Equatable, Hashable {
    case readOnly
    case readWrite
}
