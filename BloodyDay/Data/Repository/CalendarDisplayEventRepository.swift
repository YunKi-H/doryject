//
//  CalendarDisplayEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

protocol CalendarDisplayEventUpdating: AnyObject {
    func displayLocalCalendar()
    func displaySharedCalendar(events: [SharedCalendarEvent])
}

final class CalendarDisplayEventRepository: EventRepository, CalendarDisplayEventUpdating {
    private let localRepository: EventRepository
    private let calendar: Calendar
    private var sharedEvents: [UserEvent]?

    var onDisplayEventsChanged: (() -> Void)?

    init(
        localRepository: EventRepository,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.localRepository = localRepository
        self.calendar = calendar
    }

    var isDisplayingSharedCalendar: Bool {
        sharedEvents != nil
    }

    func displayLocalCalendar() {
        guard sharedEvents != nil else { return }
        sharedEvents = nil
        onDisplayEventsChanged?()
    }

    func displaySharedCalendar(events: [SharedCalendarEvent]) {
        sharedEvents = events.compactMap { event in
            guard let date = event.day.date(in: calendar) else { return nil }
            return UserEvent(
                id: event.id,
                date: date,
                type: event.type,
                calendar: calendar
            )
        }
        onDisplayEventsChanged?()
    }

    func save(_ event: UserEvent) {
        guard isDisplayingSharedCalendar == false else { return }
        localRepository.save(event)
    }

    func delete(id: UUID) {
        guard isDisplayingSharedCalendar == false else { return }
        localRepository.delete(id: id)
    }

    func delete(type: EventType, on: Date) {
        guard isDisplayingSharedCalendar == false else { return }
        localRepository.delete(type: type, on: on)
    }

    func replace(type: EventType, on dates: Set<Date>) {
        guard isDisplayingSharedCalendar == false else { return }
        localRepository.replace(type: type, on: dates)
    }

    func allEvents() -> [UserEvent] {
        sharedEvents ?? localRepository.allEvents()
    }

    func events(forMonth month: Date) -> [UserEvent] {
        guard let sharedEvents else {
            return localRepository.events(forMonth: month)
        }
        return sharedEvents.filter {
            $0.date.isInSameMonth(as: month, calendar: calendar)
        }
    }

    func events(of type: EventType) -> [UserEvent] {
        guard let sharedEvents else {
            return localRepository.events(of: type)
        }
        return sharedEvents.filter { $0.type == type }
    }

    func pillCycles() -> [PillCycleInfo] {
        guard isDisplayingSharedCalendar == false else { return [] }
        return localRepository.pillCycles()
    }
}
