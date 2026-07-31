//
//  CalendarDisplayEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

protocol CalendarDisplayEventUpdating: AnyObject {
    func displayLocalCalendar()
    func prepareSharedCalendar(
        connectionID: String,
        computationSettings: SharedCalendarComputationSettings?
    )
    func displaySharedCalendar(snapshot: SharedCalendarSnapshot)
}

final class CalendarDisplayEventRepository:
    EventRepository,
    SettingsRepository,
    CalendarDisplayEventUpdating
{
    private let localRepository: EventRepository
    private let localSettingsRepository: SettingsRepository
    private let runtimeStore: CalendarSharingRuntimeStore
    private let calendar: Calendar
    private var sharedEvents: [UserEvent]?
    private var runtimeState: CalendarSharingRuntimeState?

    var onDisplayEventsChanged: (() -> Void)?

    init(
        localRepository: EventRepository,
        localSettingsRepository: SettingsRepository = UserDefaultsSettingsRepository(),
        runtimeStore: CalendarSharingRuntimeStore = .init(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.localRepository = localRepository
        self.localSettingsRepository = localSettingsRepository
        self.runtimeStore = runtimeStore
        self.calendar = calendar
        let state = runtimeStore.load()
        self.runtimeState = state
        self.sharedEvents = state.map {
            Self.makeUserEvents(
                from: $0.events.map(\.sharedEvent),
                calendar: calendar
            )
        }
    }

    var isDisplayingSharedCalendar: Bool {
        sharedEvents != nil
    }

    func displayLocalCalendar() {
        guard sharedEvents != nil else { return }
        runtimeStore.clear()
        runtimeState = nil
        sharedEvents = nil
        onDisplayEventsChanged?()
    }

    func prepareSharedCalendar(
        connectionID: String,
        computationSettings: SharedCalendarComputationSettings?
    ) {
        let cachedEvents: [CachedSharedCalendarEvent]
        let resolvedSettings: SharedCalendarComputationSettings?
        if runtimeState?.viewerConnectionID == connectionID {
            cachedEvents = runtimeState?.events ?? []
            resolvedSettings = computationSettings
                ?? runtimeState?.computationSettings
        } else {
            cachedEvents = []
            resolvedSettings = computationSettings
        }
        let state = CalendarSharingRuntimeState(
            viewerConnectionID: connectionID,
            events: cachedEvents,
            pillCycles: runtimeState?.viewerConnectionID == connectionID
                ? runtimeState?.pillCycles ?? []
                : [],
            computationSettings: resolvedSettings
        )
        runtimeState = state
        runtimeStore.save(state)
        sharedEvents = Self.makeUserEvents(
            from: cachedEvents.map(\.sharedEvent),
            calendar: calendar
        )
        onDisplayEventsChanged?()
    }

    func displaySharedCalendar(snapshot: SharedCalendarSnapshot) {
        guard var state = runtimeState else { return }
        state.events = snapshot.events.map(CachedSharedCalendarEvent.init)
        state.pillCycles = snapshot.pillCycles.map(
            CachedSharedPillCycleMetadata.init
        )
        runtimeState = state
        runtimeStore.save(state)
        sharedEvents = Self.makeUserEvents(
            from: snapshot.events,
            calendar: calendar
        )
        onDisplayEventsChanged?()
    }

    func save(_ event: UserEvent) -> EventMutationResult {
        guard isDisplayingSharedCalendar == false else {
            return .failed(EventRepositoryMutationError.readOnlyCalendar)
        }
        return localRepository.save(event)
    }

    func delete(id: UUID) -> EventMutationResult {
        guard isDisplayingSharedCalendar == false else {
            return .failed(EventRepositoryMutationError.readOnlyCalendar)
        }
        return localRepository.delete(id: id)
    }

    func delete(type: EventType, on: Date) -> EventMutationResult {
        guard isDisplayingSharedCalendar == false else {
            return .failed(EventRepositoryMutationError.readOnlyCalendar)
        }
        return localRepository.delete(type: type, on: on)
    }

    func replace(type: EventType, on dates: Set<Date>) -> EventMutationResult {
        guard isDisplayingSharedCalendar == false else {
            return .failed(EventRepositoryMutationError.readOnlyCalendar)
        }
        return localRepository.replace(type: type, on: dates)
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
        guard let sharedEvents else {
            return localRepository.pillCycles()
        }
        var intakeDatesByCycleID: [UUID: [Date]] = [:]
        for event in sharedEvents where event.type == .pill {
            guard let cycleID = event.pillCycleID else { continue }
            intakeDatesByCycleID[cycleID, default: []].append(
                event.resolvedDate(calendar: calendar)
            )
        }
        intakeDatesByCycleID = intakeDatesByCycleID.mapValues {
            $0.sorted()
        }

        return (runtimeState?.pillCycles ?? []).compactMap { cached in
            let metadata = cached.sharedMetadata
            guard let intakeDates = intakeDatesByCycleID[metadata.id],
                  intakeDates.isEmpty == false else {
                return nil
            }
            return PillCycleInfo(
                id: metadata.id,
                intakeDates: intakeDates,
                plannedPillCount: metadata.plannedPillCount,
                breakDays: metadata.breakDays,
                autoRecordEnabled: metadata.autoRecordEnabled,
                status: metadata.status
            )
        }
    }

    func load() -> UserSettings {
        guard isDisplayingSharedCalendar else {
            return localSettingsRepository.load()
        }
        return runtimeState?.computationSettings?.makeUserSettings() ?? .init()
    }

    func save(_ settings: UserSettings) {
        guard isDisplayingSharedCalendar == false else { return }
        localSettingsRepository.save(settings)
    }

    private static func makeUserEvents(
        from events: [SharedCalendarEvent],
        calendar: Calendar
    ) -> [UserEvent] {
        events.compactMap { event in
            guard let date = event.day.date(in: calendar) else { return nil }
            return UserEvent(
                id: event.id,
                date: date,
                type: event.type,
                pillCycleID: event.pillCycleID,
                calendar: calendar
            )
        }
    }
}
