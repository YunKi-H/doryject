//
//  WidgetSnapshotBuilder.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/22/26.
//

import Foundation

enum WidgetSnapshotBuilder {
    static func build(
        today: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> WidgetSnapshot {
        let normalizedToday = calendar.startOfDay(for: today)
        let runtimeState = CalendarSharingRuntimeStore().load()
        let settings = runtimeState.map {
            $0.computationSettings?.makeUserSettings() ?? .init()
        } ?? loadSettings()
        let events = runtimeState.map {
            makeUserEvents(from: $0.events, calendar: calendar)
        } ?? WidgetSharedEventStore.allEvents()
        let pillCycles = runtimeState.map {
            makePillCycles(from: $0, calendar: calendar)
        } ?? WidgetSharedEventStore.pillCycles()
        let todayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: normalizedToday) }
        let todayEventTypes = Set(todayEvents.map(\.type))
        let eventsByType = Dictionary(grouping: events, by: \.type)
        let pillDates = Set((eventsByType[.pill] ?? []).map {
            calendar.startOfDay(for: $0.date)
        })
        let periodEvents = eventsByType[.period] ?? []
        let periodDates = periodEvents.map(\.date)
        let monthStart = normalizedToday.startOfMonth(in: calendar)
        let bounds = (
            start: monthStart.startOfCalendarGrid(calendar: calendar),
            endExclusive: monthStart.endOfCalendarGridExclusiveStart(
                calendar: calendar
            )
        )
        let context = BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: events,
            allPeriodEvents: periodEvents,
            allPillDates: pillDates,
            pillCycles: pillCycles,
            settings: settings,
            today: normalizedToday,
            calendar: calendar
        )
        let todayKey = calendar.startOfDay(for: normalizedToday)
        var dayEvents = context.eventsByDay[todayKey] ?? []
        for type in context.predictedEventsByDay[todayKey] ?? [] where !dayEvents.contains(where: { $0.type == type }) {
            dayEvents.append(DayEvent(type: type))
        }
        
        let primary = DayInfoCardStatusUseCase.primaryStatus(
            for: normalizedToday,
            today: normalizedToday,
            periodDates: periodDates,
            pillDates: pillDates,
            pillCycles: pillCycles,
            settings: settings,
            calendar: calendar
        )
        let secondary = DayInfoCardStatusUseCase.secondaryStatus(
            for: normalizedToday,
            allEventsEmpty: events.isEmpty,
            isPillEnabled: settings.pill.pillEnabled,
            dayEvents: dayEvents,
            pillDates: pillDates,
            pillCycles: pillCycles,
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
            primarySubText: WidgetDisplayMapper.primarySubText(
                from: primary,
                referenceDate: normalizedToday,
                calendar: calendar
            ),
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

    private static func makeUserEvents(
        from events: [CachedSharedCalendarEvent],
        calendar: Calendar
    ) -> [UserEvent] {
        events.compactMap { cachedEvent in
            guard let date = cachedEvent.day.date(in: calendar) else {
                return nil
            }
            return UserEvent(
                id: cachedEvent.id,
                date: date,
                type: cachedEvent.type,
                pillCycleID: cachedEvent.pillCycleID,
                calendar: calendar
            )
        }
    }

    private static func makePillCycles(
        from state: CalendarSharingRuntimeState,
        calendar: Calendar
    ) -> [PillCycleInfo] {
        var intakeDatesByCycleID: [UUID: [Date]] = [:]
        for event in state.events where event.type == .pill {
            guard let cycleID = event.pillCycleID,
                  let date = event.day.date(in: calendar) else {
                continue
            }
            intakeDatesByCycleID[cycleID, default: []].append(date)
        }

        return state.pillCycles.compactMap { cached in
            guard let intakeDates = intakeDatesByCycleID[cached.id],
                  intakeDates.isEmpty == false else {
                return nil
            }
            return PillCycleInfo(
                id: cached.id,
                intakeDates: intakeDates.sorted(),
                plannedPillCount: cached.plannedPillCount,
                breakDays: cached.breakDays,
                autoRecordEnabled: cached.autoRecordEnabled,
                status: cached.status
            )
        }
    }
}
