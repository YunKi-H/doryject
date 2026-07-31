//
//  AppleCalendarSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct AppleCalendarSettings: Codable {
    var isEnabled: Bool = false
    var eventSyncEnabled: [EventType: Bool] = Self.defaultEventSyncEnabled
    var calendarNames: [EventType: String] = Self.defaultCalendarNames
    var calendarIdentifiers: [EventType: String] = [:]
    var calendarOwnership: [EventType: Bool] = [:]
    var lastSyncedAt: Date? = nil
    
    static let defaultEventSyncEnabled: [EventType: Bool] = [
        .period: false,
        .pill: false,
        .love: false
    ]
    
    static let defaultCalendarNames: [EventType: String] = [
        .period: "🩸B-Day",
        .pill: "💊피임약 복용",
        .love: "💗사랑한 날"
    ]

    init(
        isEnabled: Bool = false,
        eventSyncEnabled: [EventType: Bool] = Self.defaultEventSyncEnabled,
        calendarNames: [EventType: String] = Self.defaultCalendarNames,
        calendarIdentifiers: [EventType: String] = [:],
        calendarOwnership: [EventType: Bool] = [:],
        lastSyncedAt: Date? = nil
    ) {
        self.isEnabled = isEnabled
        self.eventSyncEnabled = eventSyncEnabled
        self.calendarNames = calendarNames
        self.calendarIdentifiers = calendarIdentifiers
        self.calendarOwnership = calendarOwnership
        self.lastSyncedAt = lastSyncedAt
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case eventSyncEnabled
        case calendarNames
        case calendarIdentifiers
        case calendarOwnership
        case lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled, default: defaults.isEnabled)
        eventSyncEnabled = try container.decode([EventType: Bool].self, forKey: .eventSyncEnabled, default: defaults.eventSyncEnabled)
        calendarNames = try container.decode([EventType: String].self, forKey: .calendarNames, default: defaults.calendarNames)
        calendarIdentifiers = try container.decode([EventType: String].self, forKey: .calendarIdentifiers, default: defaults.calendarIdentifiers)
        calendarOwnership = try container.decode([EventType: Bool].self, forKey: .calendarOwnership, default: defaults.calendarOwnership)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }
}
