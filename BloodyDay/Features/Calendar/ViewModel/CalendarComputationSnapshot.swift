//
//  CalendarComputationSnapshot.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation

struct CalendarComputationSnapshot {
    let allEvents: [UserEvent]
    let eventsByType: [EventType: [UserEvent]]
    let eventDatesByType: [EventType: Set<Date>]
    let pillCycles: [PillCycleInfo]
    let settings: UserSettings
    let today: Date
    let calendar: Calendar

    init(
        allEvents: [UserEvent],
        pillCycles: [PillCycleInfo],
        settings: UserSettings,
        today: Date,
        calendar: Calendar
    ) {
        let normalizedToday = calendar.startOfDay(for: today)
        let eventsByType = Dictionary(grouping: allEvents, by: \.type)
        let eventDatesByType = eventsByType.mapValues { events in
            Set(events.map { calendar.startOfDay(for: $0.date) })
        }

        self.allEvents = allEvents
        self.eventsByType = eventsByType
        self.eventDatesByType = eventDatesByType
        self.pillCycles = pillCycles
        self.settings = settings
        self.today = normalizedToday
        self.calendar = calendar
    }

    func events(of type: EventType) -> [UserEvent] {
        eventsByType[type] ?? []
    }

    func dates(of type: EventType) -> Set<Date> {
        eventDatesByType[type] ?? []
    }
}
