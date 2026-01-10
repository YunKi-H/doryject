//
//  AppleCalendarSyncStore.swift
//  BloodyDay
//
//  Created by Yunki on 1/10/26.
//

import Foundation

struct AppleCalendarSyncRecord: Codable {
    let userEventId: UUID
    let eventType: EventType
    let calendarIdentifier: String
    let ekEventIdentifier: String
    let lastSyncedAt: Date
}

protocol AppleCalendarSyncStore {
    func record(for eventId: UUID) -> AppleCalendarSyncRecord?
    func records() -> [AppleCalendarSyncRecord]
    func upsert(_ record: AppleCalendarSyncRecord)
    func remove(for eventId: UUID)
    func removeAll()
}
