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
}
