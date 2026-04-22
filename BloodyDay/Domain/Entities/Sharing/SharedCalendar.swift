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
    var predictionSettings: SharedCalendarPredictionSettings
    var permission: SharedCalendarPermission
    var acceptedAt: Date?
    var updatedAt: Date?
    var cloudRecordName: String?
    var cloudZoneName: String?
    var cloudOwnerName: String?
    var cloudShareRecordName: String?
    
    init(
        id: String,
        ownerDisplayName: String? = nil,
        remoteTitle: String? = nil,
        localDisplayName: String? = nil,
        sharedEventTypes: SharedEventTypeSelection = .none,
        predictionSettings: SharedCalendarPredictionSettings = .init(),
        permission: SharedCalendarPermission = .readOnly,
        acceptedAt: Date? = nil,
        updatedAt: Date? = nil,
        cloudRecordName: String? = nil,
        cloudZoneName: String? = nil,
        cloudOwnerName: String? = nil,
        cloudShareRecordName: String? = nil
    ) {
        self.id = id
        self.ownerDisplayName = ownerDisplayName
        self.remoteTitle = remoteTitle
        self.localDisplayName = localDisplayName
        self.sharedEventTypes = sharedEventTypes
        self.predictionSettings = predictionSettings
        self.permission = permission
        self.acceptedAt = acceptedAt
        self.updatedAt = updatedAt
        self.cloudRecordName = cloudRecordName
        self.cloudZoneName = cloudZoneName
        self.cloudOwnerName = cloudOwnerName
        self.cloudShareRecordName = cloudShareRecordName
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case ownerDisplayName
        case remoteTitle
        case localDisplayName
        case sharedEventTypes
        case predictionSettings
        case permission
        case acceptedAt
        case updatedAt
        case cloudRecordName
        case cloudZoneName
        case cloudOwnerName
        case cloudShareRecordName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerDisplayName = try container.decodeIfPresent(String.self, forKey: .ownerDisplayName)
        remoteTitle = try container.decodeIfPresent(String.self, forKey: .remoteTitle)
        localDisplayName = try container.decodeIfPresent(String.self, forKey: .localDisplayName)
        sharedEventTypes = try container.decodeIfPresent(SharedEventTypeSelection.self, forKey: .sharedEventTypes) ?? .none
        predictionSettings = try container.decodeIfPresent(SharedCalendarPredictionSettings.self, forKey: .predictionSettings) ?? .init()
        permission = try container.decodeIfPresent(SharedCalendarPermission.self, forKey: .permission) ?? .readOnly
        acceptedAt = try container.decodeIfPresent(Date.self, forKey: .acceptedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        cloudRecordName = try container.decodeIfPresent(String.self, forKey: .cloudRecordName)
        cloudZoneName = try container.decodeIfPresent(String.self, forKey: .cloudZoneName)
        cloudOwnerName = try container.decodeIfPresent(String.self, forKey: .cloudOwnerName)
        cloudShareRecordName = try container.decodeIfPresent(String.self, forKey: .cloudShareRecordName)
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

struct SharedCalendarPredictionSettings: Codable, Equatable, Hashable {
    var autoCyclePredictionEnabled: Bool
    var averageCycleDays: Int?
    var averagePeriodDays: Int?
    var pillEnabled: Bool
    var pillAutoRecordEnabled: Bool
    var pillCount: Int
    var pillBreakDuration: Int
    
    init(
        autoCyclePredictionEnabled: Bool = true,
        averageCycleDays: Int? = nil,
        averagePeriodDays: Int? = nil,
        pillEnabled: Bool = false,
        pillAutoRecordEnabled: Bool = false,
        pillCount: Int = 21,
        pillBreakDuration: Int = 7
    ) {
        self.autoCyclePredictionEnabled = autoCyclePredictionEnabled
        self.averageCycleDays = averageCycleDays
        self.averagePeriodDays = averagePeriodDays
        self.pillEnabled = pillEnabled
        self.pillAutoRecordEnabled = pillAutoRecordEnabled
        self.pillCount = pillCount
        self.pillBreakDuration = pillBreakDuration
    }
}
