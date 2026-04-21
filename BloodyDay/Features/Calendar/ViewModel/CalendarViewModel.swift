//
//  CalendarViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import Foundation
import Observation

@Observable
final class CalendarViewModel {
    var selectedDate: Date = .now
    private(set) var calendarScope: CalendarScope = .mine
    
    var months: [MonthInfo] = []
    var currentIndex: Int = 0
    
    private let eventRepository: EventRepository
    private let settingsRepository: SettingsRepository?
    private let sharedCalendarRepository: SharedCalendarRepository?
    
    init(
        eventRepository: EventRepository,
        settingsRepository: SettingsRepository? = nil,
        sharedCalendarRepository: SharedCalendarRepository? = nil
    ) {
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        self.sharedCalendarRepository = sharedCalendarRepository
        self.calendarScope = settingsRepository?.load().calendarScope.selectedScope ?? .mine
        
        bootstrapMonths(anchor: selectedDate)
    }
    
    func refresh() {
        reloadCalendarScope()
        if months.isEmpty {
            bootstrapMonths(anchor: selectedDate)
            return
        }
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    func moveSelectedDate(by days: Int) {
        let calendar = Calendar.current
        let next = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        selectDate(next)
    }
    
    func toggleStatesForSelectedDate() -> (period: Bool, pill: Bool, love: Bool) {
        guard canEditEvents else {
            return (period: false, pill: false, love: false)
        }
        
        return (
            isEventOnSelectedDate(.period),
            isEventOnSelectedDate(.pill),
            isEventOnSelectedDate(.love)
        )
    }
    
    var canEditEvents: Bool {
        calendarScope.isEditable
    }
    
    var calendarScopeDisplayName: String {
        switch calendarScope {
        case .mine:
            return calendarScope.fallbackDisplayName
        case .shared(let id):
            return sharedCalendarRepository?.calendar(id: id)?.displayName ?? calendarScope.fallbackDisplayName
        }
    }
    
    func selectCalendarScope(_ scope: CalendarScope) {
        calendarScope = scope
        settingsRepository?.update {
            $0.calendarScope.selectedScope = scope
        }
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    private func reloadCalendarScope() {
        calendarScope = settingsRepository?.load().calendarScope.selectedScope ?? .mine
    }
}

// Repository
extension CalendarViewModel {
    func isEventOnSelectedDate(_ type: EventType) -> Bool {
        let target = selectedDate.startOfDay
        return events(of: type).contains { $0.date.startOfDay == target }
    }
    
    func setEvent(_ type: EventType, enabled: Bool) {
        guard canEditEvents else { return }
        
        let date = selectedDate.startOfDay
        let settings = settingsRepository?.load() ?? .init()
        let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
            type: type,
            enabled: enabled,
            selectedDate: date,
            existingDatesByType: existingEventDatesByType(),
            settings: settings,
            calendar: .current
        )
        guard plan.isEmpty == false else { return }
        applyMutationPlan(plan)
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : date.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    func pillDisableConfirmationPlanForSelectedDate() -> PillDisableConfirmationPlan? {
        guard canEditEvents else { return nil }
        
        guard let settings = settingsRepository?.load() else {
            return nil
        }
        let pillDates = Set(events(of: .pill).map { $0.date.startOfDay })
        return CalendarEventTogglePolicyUseCase.pillDisableConfirmationPlan(
            selectedDate: selectedDate,
            pillDates: pillDates,
            settings: settings,
            calendar: .current
        )
    }
    
    func deletePillEvents(on dates: [Date]) {
        guard canEditEvents else { return }
        
        applyMutationPlan(.init(deletions: [CalendarEventMutation(type: .pill, dates: dates)]))
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    private func existingEventDatesByType() -> [EventType: Set<Date>] {
        let supportedTypes: [EventType] = [.period, .pill, .love, .ovulation, .fertile, .delayed]
        return Dictionary(uniqueKeysWithValues: supportedTypes.map { type in
            let dates = Set(events(of: type).map { $0.date.startOfDay })
            return (type, dates)
        })
    }
    
    private func allEvents() -> [UserEvent] {
        switch calendarScope {
        case .mine:
            return eventRepository.allEvents()
        case .shared(let id):
            return sharedDisplayEvents(calendarId: id)
        }
    }
    
    private func events(of type: EventType) -> [UserEvent] {
        switch calendarScope {
        case .mine:
            return eventRepository.events(of: type)
        case .shared(let id):
            return sharedDisplayEvents(calendarId: id).filter { $0.type == type }
        }
    }
    
    private func sharedDisplayEvents(calendarId: String) -> [UserEvent] {
        sharedCalendarRepository?
            .visibleEvents(calendarId: calendarId)
            .map(makeDisplayEvent(from:)) ?? []
    }
    
    private func makeDisplayEvent(from sharedEvent: SharedCalendarEvent) -> UserEvent {
        UserEvent(
            id: UUID(uuidString: sharedEvent.id) ?? UUID(),
            date: sharedEvent.date,
            type: sharedEvent.type
        )
    }
    
    private func applyMutationPlan(_ plan: CalendarEventMutationPlan) {
        var existingDatesCache: [EventType: Set<Date>] = [:]
        
        func existingDates(for type: EventType) -> Set<Date> {
            if let cached = existingDatesCache[type] {
                return cached
            }
            let loaded = Set(eventRepository.events(of: type).map { $0.date.startOfDay })
            existingDatesCache[type] = loaded
            return loaded
        }
        
        for mutation in plan.deletions {
            var typeDates = existingDates(for: mutation.type)
            for date in mutation.dates.map(\.startOfDay) {
                eventRepository.delete(type: mutation.type, on: date)
                typeDates.remove(date)
            }
            existingDatesCache[mutation.type] = typeDates
        }
        
        for mutation in plan.additions {
            var typeDates = existingDates(for: mutation.type)
            for date in mutation.dates.map(\.startOfDay) {
                guard typeDates.contains(date) == false else { continue }
                eventRepository.save(UserEvent(id: .init(), date: date, type: mutation.type))
                typeDates.insert(date)
            }
            existingDatesCache[mutation.type] = typeDates
        }
    }
}

// UI
extension CalendarViewModel {
    func selectDate(_ date: Date) {
        if !selectedDate.isInSameMonth(as: date) {
            setCurrentMonth(to: date)
        }
        selectedDate = date
    }
    
    func setCurrentMonth(to month: Date) {
        let start = month.startOfMonth
        
        if let idx = months.firstIndex(where: { $0.monthDate == start }) {
            currentIndex = idx
            loadPreviousIfNeeded(viewingIndex: currentIndex)
            loadNextIfNeeded(viewingIndex: currentIndex)
        } else {
            bootstrapMonths(anchor: start)
        }
    }
    
    private func loadPreviousIfNeeded(viewingIndex index: Int) {
        guard months.indices.contains(index), index <= 1, let first = months.first?.monthDate else { return }
        let prev = first.addingMonths(-1).startOfMonth
        let monthDates = [prev] + months.map(\.monthDate)
        let keepingMonth = months[index].monthDate
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard months.indices.contains(index), index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = last.addingMonths(+1).startOfMonth
        let monthDates = months.map(\.monthDate) + [next]
        let keepingMonth = months[index].monthDate
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func bootstrapMonths(anchor: Date) {
        let anchorMonth = anchor.startOfMonth
        let monthDates = [
            anchorMonth.addingMonths(-1),
            anchorMonth,
            anchorMonth.addingMonths(1)
        ]
        rebuildMonths(monthDates: monthDates, keepingMonth: anchorMonth)
    }
    
    private func recomputeLoadedMonths(keepingMonth: Date) {
        if months.isEmpty {
            bootstrapMonths(anchor: keepingMonth)
            return
        }
        
        let monthDates = months.map(\.monthDate)
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func rebuildMonths(monthDates: [Date], keepingMonth: Date) {
        let result = BuildCalendarMonthsUseCase.execute(
            monthDates: monthDates,
            keepingMonth: keepingMonth,
            previousCurrentIndex: currentIndex,
            allEvents: allEvents(),
            buildContext: { bounds, userEvents in
                self.buildMonthComputationContext(bounds: bounds, userEvents: userEvents)
            },
            makeMonthInfo: { month, userEvents, context in
                self.makeMonthInfo(for: month, userEvents: userEvents, context: context)
            }
        )
        months = result.months
        currentIndex = result.currentIndex
    }
    
    private func buildMonthComputationContext(
        bounds: (start: Date, endExclusive: Date),
        userEvents: [UserEvent]
    ) -> MonthComputationContext {
        let settings = effectiveSettingsForCurrentScope()
        let pillDates = Set(events(of: .pill).map { $0.date.startOfDay })
        let allPeriodEvents = events(of: .period)
        return BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: userEvents,
            allPeriodEvents: allPeriodEvents,
            allPillDates: pillDates,
            settings: settings,
            today: Date(),
            calendar: .current
        )
    }
    
    private func makeMonthInfo(for month: Date, userEvents: [UserEvent], context: MonthComputationContext) -> MonthInfo {
        BuildCalendarMonthInfoUseCase.execute(
            month: month,
            userEvents: userEvents,
            context: context
        )
    }
    
    private var isPillEnabled: Bool {
        effectiveSettingsForCurrentScope().pill.pillEnabled
    }
    
    private func effectiveSettingsForCurrentScope() -> UserSettings {
        switch calendarScope {
        case .mine:
            return settingsRepository?.load() ?? .init()
        case .shared(let id):
            guard let sharedCalendar = sharedCalendarRepository?.calendar(id: id) else {
                return .init(calendarScope: .init(selectedScope: calendarScope))
            }
            return sharedCalendar
                .predictionSettings
                .asUserSettings(
                    for: calendarScope,
                    sharedEventTypes: sharedCalendar.sharedEventTypes
                )
        }
    }
}

// DayInfoCard
extension CalendarViewModel {
    func primaryStatus(for date: Date) -> CalendarPrimaryStatus {
        let settings = effectiveSettingsForCurrentScope()
        let periodDates = events(of: .period).map(\.date)
        let pillDates = Set(events(of: .pill).map { $0.date.startOfDay })
        let snapshot = DayInfoCardStatusUseCase.primaryStatus(
            for: date,
            today: Date(),
            periodDates: periodDates,
            pillDates: pillDates,
            settings: settings,
            calendar: .current
        )
        return CalendarStatusMapper.map(snapshot)
    }
    
    func secondaryStatus(for date: Date) -> CalendarSecondaryStatus {
        let settings = effectiveSettingsForCurrentScope()
        let pillDates = Set(events(of: .pill).map { $0.date.startOfDay })
        let dayEvents = months
            .flatMap(\.days)
            .first(where: { $0.date.isSameDay(as: date) })?
            .events
        
        let snapshot = DayInfoCardStatusUseCase.secondaryStatus(
            for: date,
            allEventsEmpty: allEvents().isEmpty,
            isPillEnabled: isPillEnabled,
            dayEvents: dayEvents,
            pillDates: pillDates,
            settings: settings,
            calendar: .current
        )
        return CalendarStatusMapper.map(snapshot)
    }
    
    private func actualPeriodSummaries() -> [PeriodSummary] {
        let events = events(of: .period)
        return PeriodSummaryBuilder.build(from: events.map { $0.date })
    }
    
}

private extension SharedCalendarPredictionSettings {
    func asUserSettings(
        for scope: CalendarScope,
        sharedEventTypes: SharedEventTypeSelection
    ) -> UserSettings {
        var periodSettings = PeriodSettings()
        periodSettings.autoCyclePredictionEnabled = autoCyclePredictionEnabled
        periodSettings.averageCycleDays = averageCycleDays
        periodSettings.averagePeriodDays = averagePeriodDays
        
        var pillSettings = PillSettings()
        pillSettings.pillEnabled = pillEnabled && sharedEventTypes.pill
        pillSettings.pillAutoRecordEnabled = pillAutoRecordEnabled && sharedEventTypes.pill
        pillSettings.pillCount = pillCount
        pillSettings.pillBreakDuration = pillBreakDuration
        
        return UserSettings(
            period: periodSettings,
            pill: pillSettings,
            notifications: .init(),
            appleCalendar: .init(),
            appearance: .init(),
            calendarScope: .init(selectedScope: scope)
        )
    }
}

enum CalendarPrimaryStatus: Equatable {
    case countdown(days: Int)
    case ongoing(day: Int)
    case bDay
    case delayed(days: Int)
    case unknown
    
    var displayText: String {
        switch self {
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
    
    var subText: String? {
        switch self {
        case .delayed(let days):
            return "(\(days)일 지연됨)"
        default:
            return nil
        }
    }
}

enum CalendarSecondaryStatus: Equatable {
    case pill(day: Int, total: Int?)
    case pillBreak(day: Int, total: Int)
    case ovulation
    case fertile
    case notFertile
    case unknown
    
    var displayText: String {
        switch self {
            
        case .pill(let day, let total):
            if let total, total > 0 {
                return "\(day)정 복용/\(total)정"
            }
            return "피임약 \(day)일째"
        case .pillBreak:
            return "휴약기"
        case .ovulation:
            return "임신 확률 높음"
        case .fertile:
            return "임신 확률 보통"
        case .notFertile:
            return "임신 확률 낮음"
        case .unknown:
            return "-"
        }
    }
    
    var subText: String? {
        switch self {
        case .pillBreak(let day, let total):
            return "(\(day)일째/\(total)일)"
        case .ovulation:
            return "(배란일)"
        case .fertile:
            return "(가임기)"
        default:
            return nil
        }
    }
}
