//
//  WidgetSnapshotBuilder.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/22/26.
//

import Foundation

enum WidgetSnapshotBuilder {
    static func build(today: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        let normalizedToday = today.startOfDay
        let settings = loadSettings()
        let events = WidgetSharedEventStore.allEvents()
        let pillDates = Set(events.filter { $0.type == .pill }.map { $0.date.startOfDay })
        let periodDates = events.filter { $0.type == .period }.map(\.date)
        let monthStart = normalizedToday.startOfMonth
        let bounds = (
            start: monthStart.startOfCalendarGrid(),
            endExclusive: monthStart.endOfCalendarGridExclusiveStart()
        )
        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: events,
            allPeriodEvents: events.filter { $0.type == .period },
            allPillDates: pillDates,
            settings: settings,
            today: normalizedToday,
            calendar: calendar
        )
        let todayKey = normalizedToday.startOfDay
        var dayEvents = context.eventsByDay[todayKey] ?? []
        for type in context.predictedEventsByDay[todayKey] ?? [] where !dayEvents.contains(where: { $0.type == type }) {
            dayEvents.append(DayEvent(type: type))
        }
        
        let primary = DayInfoCardStatusUseCase.primaryStatus(
            for: normalizedToday,
            today: normalizedToday,
            periodDates: periodDates,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        let secondary = DayInfoCardStatusUseCase.secondaryStatus(
            for: normalizedToday,
            allEventsEmpty: events.isEmpty,
            isPillEnabled: settings.pill.pillEnabled,
            dayEvents: dayEvents,
            pillDates: pillDates,
            settings: settings,
            calendar: calendar
        )
        
        var chips: [WidgetChipSnapshot] = []
        if let chip = secondaryChip(from: secondary) {
            chips.append(chip)
        }
        if events.contains(where: { $0.type == .love && calendar.isDate($0.date, inSameDayAs: normalizedToday) }) {
            chips.append(.init(id: "love", kind: .love, text: "사랑한 날", subText: nil))
        }
        
        return WidgetSnapshot(
            generatedAt: normalizedToday,
            primaryText: primaryText(from: primary),
            primarySubText: primarySubText(from: primary),
            chips: chips,
            toggles: .init(
                period: events.contains(where: { $0.type == .period && calendar.isDate($0.date, inSameDayAs: normalizedToday) }),
                pill: events.contains(where: { $0.type == .pill && calendar.isDate($0.date, inSameDayAs: normalizedToday) }),
                love: events.contains(where: { $0.type == .love && calendar.isDate($0.date, inSameDayAs: normalizedToday) })
            )
        )
    }
    
    private static func loadSettings() -> UserSettings {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.appGroupIdentifier),
              let data = defaults.data(forKey: "user.settings.v1"),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return .init()
        }
        return settings
    }
    
    private static func primaryText(from snapshot: DayInfoCardPrimarySnapshot) -> String {
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
    
    private static func primarySubText(from snapshot: DayInfoCardPrimarySnapshot) -> String? {
        switch snapshot {
        case .delayed(let days):
            return "(\(days)일 지연됨)"
        default:
            return nil
        }
    }
    
    private static func secondaryChip(from snapshot: DayInfoCardSecondarySnapshot) -> WidgetChipSnapshot? {
        switch snapshot {
        case .pill(let day, let total):
            if let total {
                return .init(id: "secondary", kind: .secondary, text: "\(day)정 복용/\(total)정", subText: nil)
            }
            return .init(id: "secondary", kind: .secondary, text: "피임약 \(day)일째", subText: nil)
        case .pillBreak(let day, let total):
            return .init(id: "secondary", kind: .secondary, text: "휴약기", subText: "(\(day)일째/\(total)일)")
        case .ovulation:
            return .init(id: "secondary", kind: .secondary, text: "임신 확률 높음", subText: "(배란일)")
        case .fertile:
            return .init(id: "secondary", kind: .secondary, text: "임신 확률 보통", subText: "(가임기)")
        case .notFertile:
            return .init(id: "secondary", kind: .secondary, text: "임신 확률 낮음", subText: nil)
        case .unknown:
            return nil
        }
    }
}
