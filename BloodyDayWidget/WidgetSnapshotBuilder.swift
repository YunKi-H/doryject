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
        let todayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: normalizedToday) }
        let todayEventTypes = Set(todayEvents.map(\.type))
        let eventsByType = Dictionary(grouping: events, by: \.type)
        let pillDates = Set((eventsByType[.pill] ?? []).map { $0.date.startOfDay })
        let periodEvents = eventsByType[.period] ?? []
        let periodDates = periodEvents.map(\.date)
        let monthStart = normalizedToday.startOfMonth
        let bounds = (
            start: monthStart.startOfCalendarGrid(),
            endExclusive: monthStart.endOfCalendarGridExclusiveStart()
        )
        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: events,
            allPeriodEvents: periodEvents,
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
        if let pillOrFertilityChip = WidgetDisplayMapper.secondaryChip(from: secondary) {
            chips.append(pillOrFertilityChip)
        }
        if let periodChip = WidgetDisplayMapper.periodChip(from: primary) {
            chips.append(periodChip)
        }
        chips.sort { lhs, rhs in
            chipPriority(lhs.kind) < chipPriority(rhs.kind)
        }
        
        return WidgetSnapshot(
            generatedAt: normalizedToday,
            primaryText: WidgetDisplayMapper.primaryText(from: primary),
            primarySubText: WidgetDisplayMapper.primarySubText(from: primary),
            chips: chips,
            toggles: .init(
                period: todayEventTypes.contains(.period),
                pill: todayEventTypes.contains(.pill),
                love: todayEventTypes.contains(.love)
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

    private static func chipPriority(_ kind: WidgetChipKind) -> Int {
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
