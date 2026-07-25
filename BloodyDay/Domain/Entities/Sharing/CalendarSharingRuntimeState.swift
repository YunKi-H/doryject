//
//  CalendarSharingRuntimeState.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import Foundation

struct SharedCalendarComputationSettings: Codable, Equatable, Sendable {
    let period: PeriodSettings
    let pill: PillSettings

    init(settings: UserSettings) {
        self.period = settings.period
        self.pill = settings.pill
    }

    init(period: PeriodSettings, pill: PillSettings) {
        self.period = period
        self.pill = pill
    }

    func makeUserSettings() -> UserSettings {
        UserSettings(period: period, pill: pill)
    }
}

struct CachedSharedCalendarEvent: Codable {
    let id: UUID
    let day: CalendarDay
    let type: EventType

    init(_ event: SharedCalendarEvent) {
        self.id = event.id
        self.day = event.day
        self.type = event.type
    }

    var sharedEvent: SharedCalendarEvent {
        SharedCalendarEvent(id: id, day: day, type: type)
    }
}

struct CalendarSharingRuntimeState: Codable {
    let viewerConnectionID: String
    var events: [CachedSharedCalendarEvent]
    var computationSettings: SharedCalendarComputationSettings?
}

struct CalendarSharingRuntimeStore {
    static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    private static let key = "calendar.sharing.runtime.v1"

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = UserDefaults(
            suiteName: CalendarSharingRuntimeStore.appGroupIdentifier
        ) ?? .standard
    ) {
        self.defaults = defaults
    }

    func load() -> CalendarSharingRuntimeState? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(
            CalendarSharingRuntimeState.self,
            from: data
        )
    }

    func save(_ state: CalendarSharingRuntimeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
