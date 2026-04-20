//
//  SharedCalendarEvent.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

struct SharedCalendarEvent: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let calendarId: String
    let sourceEventId: String?
    let type: EventType
    let date: Date
    let updatedAt: Date
    let deletedAt: Date?
    
    init(
        id: String,
        calendarId: String,
        sourceEventId: String? = nil,
        type: EventType,
        date: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.calendarId = calendarId
        self.sourceEventId = sourceEventId
        self.type = type
        self.date = date.startOfDay
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    var isDeleted: Bool {
        deletedAt != nil
    }
}
