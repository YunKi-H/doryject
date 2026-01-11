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
}
