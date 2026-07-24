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
    var selectedDate: Date
    
    var months: [MonthInfo] = []
    var currentIndex: Int = 0
    private(set) var referenceToday: Date
    
    private let eventRepository: EventRepository
    private let settingsRepository: SettingsRepository?
    private var calendar: Calendar
    private var computationSnapshot: CalendarComputationSnapshot
    private var selectedDayComponents: DateComponents
    private var visibleMonthComponents: DateComponents
    
    init(
        eventRepository: EventRepository,
        settingsRepository: SettingsRepository? = nil,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let normalizedToday = calendar.startOfDay(for: now)
        self.selectedDate = normalizedToday
        self.referenceToday = normalizedToday
        self.selectedDayComponents = Self.civilDayComponents(
            from: normalizedToday,
            calendar: calendar
        )
        self.visibleMonthComponents = Self.civilMonthComponents(
            from: normalizedToday,
            calendar: calendar
        )
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        self.calendar = calendar
        self.computationSnapshot = Self.makeComputationSnapshot(
            eventRepository: eventRepository,
            settingsRepository: settingsRepository,
            today: normalizedToday,
            calendar: calendar
        )
        
        bootstrapMonths(anchor: selectedDate)
    }
    
    func refresh(now: Date = .now) {
        referenceToday = calendar.startOfDay(for: now)
        reloadComputationSnapshot()
        if months.isEmpty {
            bootstrapMonths(anchor: selectedDate)
            return
        }
        let keepingMonth = months.indices.contains(currentIndex)
            ? months[currentIndex].monthDate
            : selectedDate.startOfMonth(in: calendar)
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }

    func refreshIfReferenceDayChanged(now: Date = .now) {
        let normalizedToday = calendar.startOfDay(for: now)
        guard normalizedToday != referenceToday else { return }
        refresh(now: normalizedToday)
    }

    func refreshForSystemCalendarChange(
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let preservedVisibleMonthComponents = visibleMonthComponents
        self.calendar = calendar
        referenceToday = calendar.startOfDay(for: now)
        reloadComputationSnapshot()
        selectedDate = Self.date(
            from: selectedDayComponents,
            calendar: calendar
        ) ?? referenceToday
        let visibleMonth = Self.date(
            from: visibleMonthComponents,
            calendar: calendar
        ) ?? selectedDate
        bootstrapMonths(anchor: visibleMonth)
        visibleMonthComponents = preservedVisibleMonthComponents
    }
    
    func moveSelectedDate(by days: Int) {
        let next = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        selectDate(next)
    }
    
    func toggleStatesForSelectedDate() -> (period: Bool, pill: Bool, love: Bool) {
        let target = calendar.startOfDay(for: selectedDate)
        return (
            computationSnapshot.dates(of: .period).contains(target),
            computationSnapshot.dates(of: .pill).contains(target),
            computationSnapshot.dates(of: .love).contains(target)
        )
    }
}

// Repository
extension CalendarViewModel {
    func isEventOnSelectedDate(_ type: EventType) -> Bool {
        let target = calendar.startOfDay(for: selectedDate)
        return computationSnapshot.dates(of: type).contains(target)
    }
    
    func setEvent(_ type: EventType, enabled: Bool) {
        let date = calendar.startOfDay(for: selectedDate)
        let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
            type: type,
            enabled: enabled,
            selectedDate: date,
            existingDatesByType: computationSnapshot.eventDatesByType,
            settings: computationSnapshot.settings,
            pillCycles: computationSnapshot.pillCycles,
            calendar: calendar
        )
        guard plan.isEmpty == false else { return }
        applyMutationPlan(plan)
        reloadComputationSnapshot()
        let keepingMonth = months.indices.contains(currentIndex)
            ? months[currentIndex].monthDate
            : date.startOfMonth(in: calendar)
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    func pillDisableConfirmationPlanForSelectedDate() -> PillDisableConfirmationPlan? {
        guard settingsRepository != nil else {
            return nil
        }
        return CalendarEventTogglePolicyUseCase.pillDisableConfirmationPlan(
            selectedDate: selectedDate,
            pillDates: computationSnapshot.dates(of: .pill),
            settings: computationSnapshot.settings,
            pillCycles: computationSnapshot.pillCycles,
            calendar: calendar
        )
    }
    
    func deletePillEvents(on dates: [Date]) {
        applyMutationPlan(.init(deletions: [CalendarEventMutation(type: .pill, dates: dates)]))
        reloadComputationSnapshot()
        let keepingMonth = months.indices.contains(currentIndex)
            ? months[currentIndex].monthDate
            : selectedDate.startOfMonth(in: calendar)
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    private func applyMutationPlan(_ plan: CalendarEventMutationPlan) {
        var existingDatesCache = computationSnapshot.eventDatesByType
        
        for mutation in plan.deletions {
            var typeDates = existingDatesCache[mutation.type] ?? []
            for date in mutation.dates.map({ calendar.startOfDay(for: $0) }) {
                eventRepository.delete(type: mutation.type, on: date)
                typeDates.remove(date)
            }
            existingDatesCache[mutation.type] = typeDates
        }
        
        for mutation in plan.additions {
            var typeDates = existingDatesCache[mutation.type] ?? []
            for date in mutation.dates.map({ calendar.startOfDay(for: $0) }) {
                guard typeDates.contains(date) == false else { continue }
                eventRepository.save(
                    UserEvent(
                        id: .init(),
                        date: date,
                        type: mutation.type,
                        calendar: calendar
                    )
                )
                typeDates.insert(date)
            }
            existingDatesCache[mutation.type] = typeDates
        }
    }
}

// UI
extension CalendarViewModel {
    func selectDate(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        if !selectedDate.isInSameMonth(as: normalizedDate, calendar: calendar) {
            setCurrentMonth(to: normalizedDate)
        }
        selectedDate = normalizedDate
        selectedDayComponents = Self.civilDayComponents(
            from: normalizedDate,
            calendar: calendar
        )
    }
    
    func setCurrentMonth(to month: Date) {
        let start = month.startOfMonth(in: calendar)
        visibleMonthComponents = Self.civilMonthComponents(
            from: start,
            calendar: calendar
        )
        
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
        let prev = first
            .addingMonths(-1, calendar: calendar)
            .startOfMonth(in: calendar)
        let monthDates = [prev] + months.map(\.monthDate)
        let keepingMonth = months[index].monthDate
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard months.indices.contains(index), index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = last
            .addingMonths(+1, calendar: calendar)
            .startOfMonth(in: calendar)
        let monthDates = months.map(\.monthDate) + [next]
        let keepingMonth = months[index].monthDate
        rebuildMonths(monthDates: monthDates, keepingMonth: keepingMonth)
    }
    
    private func bootstrapMonths(anchor: Date) {
        let anchorMonth = anchor.startOfMonth(in: calendar)
        let monthDates = [
            anchorMonth.addingMonths(-1, calendar: calendar),
            anchorMonth,
            anchorMonth.addingMonths(1, calendar: calendar)
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
            allEvents: computationSnapshot.allEvents,
            calendar: calendar,
            buildContext: { bounds, userEvents in
                self.buildMonthComputationContext(bounds: bounds, userEvents: userEvents)
            },
            makeMonthInfo: { month, userEvents, context in
                self.makeMonthInfo(for: month, userEvents: userEvents, context: context)
            }
        )
        months = result.months
        currentIndex = result.currentIndex
        if months.indices.contains(currentIndex) {
            visibleMonthComponents = Self.civilMonthComponents(
                from: months[currentIndex].monthDate,
                calendar: calendar
            )
        }
    }
    
    private func buildMonthComputationContext(
        bounds: (start: Date, endExclusive: Date),
        userEvents: [UserEvent]
    ) -> MonthComputationContext {
        return BuildCalendarMonthComputationContextUseCase.execute(
            bounds: bounds,
            userEvents: userEvents,
            allPeriodEvents: computationSnapshot.events(of: .period),
            allPillDates: computationSnapshot.dates(of: .pill),
            pillCycles: computationSnapshot.pillCycles,
            settings: computationSnapshot.settings,
            today: computationSnapshot.today,
            calendar: calendar
        )
    }
    
    private func makeMonthInfo(for month: Date, userEvents: [UserEvent], context: MonthComputationContext) -> MonthInfo {
        BuildCalendarMonthInfoUseCase.execute(
            month: month,
            userEvents: userEvents,
            context: context,
            calendar: calendar
        )
    }
    
    private func reloadComputationSnapshot() {
        computationSnapshot = Self.makeComputationSnapshot(
            eventRepository: eventRepository,
            settingsRepository: settingsRepository,
            today: referenceToday,
            calendar: calendar
        )
    }

    private static func makeComputationSnapshot(
        eventRepository: EventRepository,
        settingsRepository: SettingsRepository?,
        today: Date,
        calendar: Calendar
    ) -> CalendarComputationSnapshot {
        CalendarComputationSnapshot(
            allEvents: eventRepository.allEvents(),
            pillCycles: eventRepository.pillCycles(),
            settings: settingsRepository?.load() ?? .init(),
            today: today,
            calendar: calendar
        )
    }

    private static func civilDayComponents(
        from date: Date,
        calendar: Calendar
    ) -> DateComponents {
        civilCalendar(timeZone: calendar.timeZone)
            .dateComponents([.year, .month, .day], from: date)
    }

    private static func civilMonthComponents(
        from date: Date,
        calendar: Calendar
    ) -> DateComponents {
        let components = civilCalendar(timeZone: calendar.timeZone)
            .dateComponents([.year, .month], from: date)
        return DateComponents(
            year: components.year,
            month: components.month,
            day: 1
        )
    }

    private static func date(
        from components: DateComponents,
        calendar: Calendar
    ) -> Date? {
        let targetCalendar = civilCalendar(timeZone: calendar.timeZone)
        return targetCalendar.date(from: components).map {
            targetCalendar.startOfDay(for: $0)
        }
    }

    private static func civilCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }
}

// DayInfoCard
extension CalendarViewModel {
    func primaryStatus(for date: Date) -> CalendarPrimaryStatus {
        let snapshot = DayInfoCardStatusUseCase.primaryStatus(
            for: date,
            today: computationSnapshot.today,
            periodDates: computationSnapshot.events(of: .period).map(\.date),
            pillDates: computationSnapshot.dates(of: .pill),
            pillCycles: computationSnapshot.pillCycles,
            settings: computationSnapshot.settings,
            calendar: calendar
        )
        return CalendarStatusMapper.map(snapshot)
    }
    
    func secondaryStatus(for date: Date) -> CalendarSecondaryStatus {
        let dayEvents = months
            .flatMap(\.days)
            .first(where: {
                $0.date.isSameDay(as: date, calendar: calendar)
            })?
            .events
        
        let snapshot = DayInfoCardStatusUseCase.secondaryStatus(
            for: date,
            allEventsEmpty: computationSnapshot.allEvents.isEmpty,
            isPillEnabled: computationSnapshot.settings.pill.pillEnabled,
            dayEvents: dayEvents,
            pillDates: computationSnapshot.dates(of: .pill),
            pillCycles: computationSnapshot.pillCycles,
            settings: computationSnapshot.settings,
            calendar: calendar
        )
        return CalendarStatusMapper.map(snapshot)
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
