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
    private static let settingsKey = "user.settings.v1"
    
    @Parameter(title: "이벤트")
    var eventType: ToggleTodayEventKind
    
    init() {}
    
    init(eventType: ToggleTodayEventKind) {
        self.eventType = eventType
    }
    
    func perform() async throws -> some IntentResult {
        let toggledOn = WidgetSharedEventStore.toggle(eventType.widgetType, on: .now)
        if eventType == .pill, toggledOn {
            enablePillIfNeeded()
        }
        if eventType != .love {
            await rescheduleNotifications()
        }
        rebuildSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
    
    private func rebuildSnapshot() {
        let store = WidgetSnapshotStore()
        store.save(WidgetSnapshotBuilder.build())
    }
    
    private func enablePillIfNeeded() {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.appGroupIdentifier) else { return }
        var settings: UserSettings
        if let data = defaults.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .init()
        }
        settings.pill.pillEnabled = true
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        defaults.set(encoded, forKey: Self.settingsKey)
    }

    private func rescheduleNotifications() async {
        let eventReader = WidgetEventReader(
            events: WidgetSharedEventStore.allEvents()
        )
        await UserNotificationScheduler().applyAndWait(
            settings: loadSettings(),
            eventReader: eventReader
        )
    }

    private func loadSettings() -> UserSettings {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.appGroupIdentifier),
              let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return .init()
        }
        return settings
    }
}

private struct WidgetEventReader: EventReading {
    let events: [UserEvent]

    func events(of type: EventType) -> [UserEvent] {
        events.filter { $0.type == type }
    }
}
