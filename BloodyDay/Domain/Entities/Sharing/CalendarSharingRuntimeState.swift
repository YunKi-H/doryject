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
    let pillCycleID: UUID?

    init(_ event: SharedCalendarEvent) {
        self.id = event.id
        self.day = event.day
        self.type = event.type
        self.pillCycleID = event.pillCycleID
    }

    var sharedEvent: SharedCalendarEvent {
        SharedCalendarEvent(
            id: id,
            day: day,
            type: type,
            pillCycleID: pillCycleID
        )
    }
}

struct CachedSharedPillCycleMetadata: Codable {
    let id: UUID
    let startDay: CalendarDay
    let plannedPillCount: Int?
    let breakDays: Int?
    let autoRecordEnabled: Bool?
    let status: PillCycleStatus

    init(_ metadata: SharedPillCycleMetadata) {
        self.id = metadata.id
        self.startDay = metadata.startDay
        self.plannedPillCount = metadata.plannedPillCount
        self.breakDays = metadata.breakDays
        self.autoRecordEnabled = metadata.autoRecordEnabled
        self.status = metadata.status
    }

    var sharedMetadata: SharedPillCycleMetadata {
        SharedPillCycleMetadata(
            id: id,
            startDay: startDay,
            plannedPillCount: plannedPillCount,
            breakDays: breakDays,
            autoRecordEnabled: autoRecordEnabled,
            status: status
        )
    }
}

struct CalendarSharingRuntimeState: Codable {
    let viewerConnectionID: String
    var events: [CachedSharedCalendarEvent]
    var pillCycles: [CachedSharedPillCycleMetadata]
    var computationSettings: SharedCalendarComputationSettings?
    var publicationVersion: String?

    init(
        viewerConnectionID: String,
        events: [CachedSharedCalendarEvent],
        pillCycles: [CachedSharedPillCycleMetadata] = [],
        computationSettings: SharedCalendarComputationSettings?,
        publicationVersion: String? = nil
    ) {
        self.viewerConnectionID = viewerConnectionID
        self.events = events
        self.pillCycles = pillCycles
        self.computationSettings = computationSettings
        self.publicationVersion = publicationVersion
    }

    private enum CodingKeys: String, CodingKey {
        case viewerConnectionID
        case events
        case pillCycles
        case computationSettings
        case publicationVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        viewerConnectionID = try container.decode(
            String.self,
            forKey: .viewerConnectionID
        )
        events = try container.decode(
            [CachedSharedCalendarEvent].self,
            forKey: .events
        )
        pillCycles = try container.decodeIfPresent(
            [CachedSharedPillCycleMetadata].self,
            forKey: .pillCycles
        ) ?? []
        computationSettings = try container.decodeIfPresent(
            SharedCalendarComputationSettings.self,
            forKey: .computationSettings
        )
        publicationVersion = try container.decodeIfPresent(
            String.self,
            forKey: .publicationVersion
        )
    }
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

enum WidgetCalendarSharingRole: String, Codable {
    case owner
    case viewer
}

struct WidgetCalendarSharingState: Codable, Equatable {
    let role: WidgetCalendarSharingRole
    let connectionID: String
}

struct WidgetCalendarSharingStateStore {
    private static let key = "calendar.sharing.widget.state.v1"

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = UserDefaults(
            suiteName: CalendarSharingRuntimeStore.appGroupIdentifier
        ) ?? .standard
    ) {
        self.defaults = defaults
    }

    func load() -> WidgetCalendarSharingState? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(
            WidgetCalendarSharingState.self,
            from: data
        )
    }

    func save(_ state: WidgetCalendarSharingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
        SharedCalendarSyncRetryStore(defaults: defaults).clear()
    }
}
