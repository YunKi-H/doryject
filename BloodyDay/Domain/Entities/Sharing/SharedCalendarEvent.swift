//
//  SharedCalendarEvent.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

struct SharedCalendarEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let day: CalendarDay
    let type: EventType
    let pillCycleID: UUID?

    init(
        id: UUID,
        day: CalendarDay,
        type: EventType,
        pillCycleID: UUID? = nil
    ) {
        self.id = id
        self.day = day
        self.type = type
        self.pillCycleID = pillCycleID
    }
}

struct SharedPillCycleMetadata: Identifiable, Equatable, Sendable {
    let id: UUID
    let startDay: CalendarDay
    let plannedPillCount: Int?
    let breakDays: Int?
    let autoRecordEnabled: Bool?
    let status: PillCycleStatus
}

struct SharedCalendarSnapshot: Equatable, Sendable {
    let events: [SharedCalendarEvent]
    let pillCycles: [SharedPillCycleMetadata]
}
