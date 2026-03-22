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
        let toggledOn = WidgetSharedEventStore.toggle(eventType.widgetType, on: .now)
        if eventType == .pill, toggledOn {
            enablePillIfNeeded()
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
        let key = "user.settings.v1"
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.appGroupIdentifier) else { return }
        
        var root: [String: Any] = [:]
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = decoded
        }
        
        var pill = root["pill"] as? [String: Any] ?? [:]
        pill["pillEnabled"] = true
        root["pill"] = pill
        
        guard let encoded = try? JSONSerialization.data(withJSONObject: root) else { return }
        defaults.set(encoded, forKey: key)
    }
}
