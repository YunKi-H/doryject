//
//  ToggleTodayEventIntent.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import Foundation
import AppIntents
import WidgetKit

enum ToggleTodayEventKind: String, AppEnum {
    case period
    case pill
    case love
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "이벤트"
    static var caseDisplayRepresentations: [ToggleTodayEventKind: DisplayRepresentation] = [
        .period: "생리",
        .pill: "피임약 복용",
        .love: "사랑한 날"
    ]
    
    var widgetType: EventType {
        switch self {
        case .period:
            return .period
        case .pill:
            return .pill
        case .love:
            return .love
        }
    }
}

struct ToggleTodayEventIntent: AppIntent {
    static let title: LocalizedStringResource = "오늘 이벤트 토글"
    static let openAppWhenRun = false
    
    @Parameter(title: "이벤트")
    var eventType: ToggleTodayEventKind
    
    init() {}
    
    init(eventType: ToggleTodayEventKind) {
        self.eventType = eventType
    }
    
    func perform() async throws -> some IntentResult {
        let sharingState = WidgetCalendarSharingStateStore().load()
        guard CalendarSharingRuntimeStore().load() == nil,
              sharingState?.role != .viewer else {
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        let settingsRepository = WidgetSettingsRepository()
        let toggledOn = WidgetSharedEventStore.toggle(eventType.widgetType, on: .now)
        if eventType == .pill, toggledOn {
            enablePillIfNeeded(settingsRepository: settingsRepository)
        }
        rebuildSnapshot()
        WidgetCenter.shared.reloadAllTimelines()

        if sharingState?.role == .owner {
            await WidgetSharedCalendarSyncService.shared
                .synchronizeOwnedCalendarIfNeeded()
            WidgetCenter.shared.reloadAllTimelines()
        }

        let eventReader = WidgetEventReader(
            events: WidgetSharedEventStore.allEvents(),
            pillCycleInfos: WidgetSharedEventStore.pillCycles()
        )
        if eventType != .love {
            await rescheduleNotifications(
                settings: settingsRepository.load(),
                eventReader: eventReader
            )
        }
        await resyncAppleCalendar(
            settingsRepository: settingsRepository,
            eventReader: eventReader
        )
        return .result()
    }
    
    private func rebuildSnapshot() {
        let store = WidgetSnapshotStore()
        store.save(WidgetSnapshotBuilder.build())
    }
    
    private func enablePillIfNeeded(settingsRepository: WidgetSettingsRepository) {
        settingsRepository.update { settings in
            settings.pill.pillEnabled = true
        }
    }

    private func rescheduleNotifications(
        settings: UserSettings,
        eventReader: WidgetEventReader
    ) async {
        await UserNotificationScheduler().applyAndWait(
            settings: settings,
            eventReader: eventReader
        )
    }

    private func resyncAppleCalendar(
        settingsRepository: WidgetSettingsRepository,
        eventReader: WidgetEventReader
    ) async {
        let syncService = AppleCalendarSyncService(
            settingsRepository: settingsRepository,
            eventRepository: eventReader,
            calendarClient: EventKitAppleCalendarClient(),
            syncStore: UserDefaultsAppleCalendarSyncStore()
        )
        await syncService.syncAll()
    }
}

private struct WidgetEventReader: EventReading {
    let events: [UserEvent]
    let pillCycleInfos: [PillCycleInfo]

    func events(of type: EventType) -> [UserEvent] {
        events.filter { $0.type == type }
    }

    func pillCycles() -> [PillCycleInfo] {
        pillCycleInfos
    }
}

private final class WidgetSettingsRepository: SettingsRepository {
    private static let settingsKey = "user.settings.v1"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(
            suiteName: WidgetSnapshotStore.appGroupIdentifier
        ) ?? .standard
    }

    func load() -> UserSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return .init()
        }
        return settings
    }

    func save(_ settings: UserSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }
}
