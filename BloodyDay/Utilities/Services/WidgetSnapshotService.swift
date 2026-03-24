//
//  WidgetSnapshotService.swift
//  BloodyDay
//
//  Created by Yunki on 3/21/26.
//

import Foundation
import WidgetKit

struct WidgetSnapshot: Codable {
    let generatedAt: Date
    let primaryText: String
    let primarySubText: String?
    let chips: [WidgetChipSnapshot]
    let toggles: WidgetToggleSnapshot
}

struct WidgetChipSnapshot: Codable, Identifiable {
    let id: String
    let kind: WidgetChipKind
    let text: String
}

enum WidgetChipKind: String, Codable {
    case period
    case pill
    case fertility
}

struct WidgetToggleSnapshot: Codable {
    let period: Bool
    let pill: Bool
    let love: Bool
}

final class WidgetSnapshotService {
    static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    
    private let eventRepository: EventRepository
    private let settingsRepository: SettingsRepository
    private let store: WidgetSnapshotStore
    
    init(
        eventRepository: EventRepository,
        settingsRepository: SettingsRepository,
        store: WidgetSnapshotStore = .init()
    ) {
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        self.store = store
    }
    
    func refresh(today: Date = Date(), calendar: Calendar = .current) {
        let snapshot = makeSnapshot(today: today, calendar: calendar)
        store.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func makeSnapshot(today: Date, calendar: Calendar) -> WidgetSnapshot {
        let normalizedToday = today.startOfDay
        let settings = settingsRepository.load()
        let allEvents = eventRepository.allEvents()
        let periodEvents = allEvents.filter { $0.type == .period }
        let pillDates = Set(allEvents.filter { $0.type == .pill }.map { $0.date.startOfDay })
        let monthStart = normalizedToday.startOfMonth
        let bounds = (
            start: monthStart.startOfCalendarGrid(),
            endExclusive: monthStart.endOfCalendarGridExclusiveStart()
        )
        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: allEvents,
            allPeriodEvents: periodEvents,
            allPillDates: pillDates,
            settings: settings,
            today: normalizedToday,
            calendar: calendar
        )
        let monthInfo = BuildCalendarMonthInfoUseCase.execute(
            month: monthStart,
            userEvents: allEvents,
            context: context
        )
        let todayEvents = monthInfo.days.first(where: { $0.date.isSameDay(as: normalizedToday) })?.events
        let primary = DayInfoCardStatusUseCase.primaryStatus(
            for: normalizedToday,
            today: normalizedToday,
            periodDates: periodEvents.map(\.date),
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        let secondary = DayInfoCardStatusUseCase.secondaryStatus(
            for: normalizedToday,
            allEventsEmpty: allEvents.isEmpty,
            isPillEnabled: settings.pill.pillEnabled,
            dayEvents: todayEvents,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        
        var chips: [WidgetChipSnapshot] = []
        if let secondaryChip = secondaryChipSnapshot(from: secondary) {
            chips.append(secondaryChip)
        }
        if let periodChip = periodChipSnapshot(from: primary) {
            chips.append(periodChip)
        }
        chips.sort { lhs, rhs in
            chipPriority(lhs.kind) < chipPriority(rhs.kind)
        }
        
        return WidgetSnapshot(
            generatedAt: normalizedToday,
            primaryText: primaryText(from: primary),
            primarySubText: primarySubText(from: primary),
            chips: chips,
            toggles: .init(
                period: allEvents.contains { $0.type == .period && $0.date.isSameDay(as: normalizedToday) },
                pill: allEvents.contains { $0.type == .pill && $0.date.isSameDay(as: normalizedToday) },
                love: allEvents.contains { $0.type == .love && $0.date.isSameDay(as: normalizedToday) }
            )
        )
    }
    
    private func primaryText(from snapshot: DayInfoCardPrimarySnapshot) -> String {
        switch snapshot {
        case .countdown(let days):
            return "B-\(days)"
        case .ongoing(let day):
            return "B+\(day)"
        case .bDay:
            return "B-Day"
        case .delayed:
            return "생리 지연"
        case .unknown:
            return "-"
        }
    }
    
    private func primarySubText(from snapshot: DayInfoCardPrimarySnapshot) -> String? {
        switch snapshot {
        case .delayed(let days):
            return "(\(days)일 지연됨)"
        default:
            return nil
        }
    }
    
    private func secondaryChipSnapshot(from snapshot: DayInfoCardSecondarySnapshot) -> WidgetChipSnapshot? {
        switch snapshot {
        case .pill(let day, let total):
            if let total, total > 0 {
                return .init(id: "pill", kind: .pill, text: "(\(day)/\(total))")
            }
            return .init(id: "pill", kind: .pill, text: "(\(day))")
        case .pillBreak(let day, let total):
            return .init(id: "pill", kind: .pill, text: "휴약기 (\(day)/\(total))")
        case .ovulation:
            return .init(id: "fertility", kind: .fertility, text: "매우높음")
        case .fertile:
            return .init(id: "fertility", kind: .fertility, text: "높음")
        case .notFertile:
            return nil
        case .unknown:
            return nil
        }
    }

    private func periodChipSnapshot(from snapshot: DayInfoCardPrimarySnapshot) -> WidgetChipSnapshot? {
        switch snapshot {
        case .ongoing, .bDay:
            return .init(id: "period", kind: .period, text: "진행")
        case .delayed:
            return .init(id: "period", kind: .period, text: "지연")
        case .countdown, .unknown:
            return nil
        }
    }

    private func chipPriority(_ kind: WidgetChipKind) -> Int {
        switch kind {
        case .pill:
            return 0
        case .fertility:
            return 1
        case .period:
            return 2
        }
    }
}

struct WidgetSnapshotStore {
    private let fileName = "widget_snapshot.json"
    private let appGroupIdentifier: String
    
    init(appGroupIdentifier: String = WidgetSnapshotService.appGroupIdentifier) {
        self.appGroupIdentifier = appGroupIdentifier
    }
    
    func load() -> WidgetSnapshot? {
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
    
    func save(_ snapshot: WidgetSnapshot) {
        guard let url = storageURL(),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
    
    private func storageURL() -> URL? {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return groupURL.appendingPathComponent(fileName)
        }
        
        let fallbackDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let fallbackDirectory else { return nil }
        try? FileManager.default.createDirectory(
            at: fallbackDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return fallbackDirectory.appendingPathComponent(fileName)
    }
}
