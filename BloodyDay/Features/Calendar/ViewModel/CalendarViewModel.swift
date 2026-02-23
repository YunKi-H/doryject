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
    
    var months: [MonthInfo] = []
    var currentIndex: Int = 0
    
    private let eventRepository: EventRepository
    private let settingsRepository: SettingsRepository?
    
    init(eventRepository: EventRepository, settingsRepository: SettingsRepository? = nil) {
        self.eventRepository = eventRepository
        self.settingsRepository = settingsRepository
        
        bootstrapMonths(anchor: selectedDate)
    }
    
    func refresh() {
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
        (
            isEventOnSelectedDate(.period),
            isEventOnSelectedDate(.pill),
            isEventOnSelectedDate(.love)
        )
    }
}

struct PillDisableConfirmationContext {
    let remainingCount: Int
    let todayOnlyDeleteDates: [Date]
    let datesToDeleteFromSelected: [Date]
}

// Repository
extension CalendarViewModel {
    func isEventOnSelectedDate(_ type: EventType) -> Bool {
        let target = selectedDate.startOfDay
        return eventRepository.events(of: type).contains { $0.date.startOfDay == target }
    }
    
    func setEvent(_ type: EventType, enabled: Bool) {
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
    
    func pillDisableConfirmationContextForSelectedDate() -> PillDisableConfirmationContext? {
        guard let settings = settingsRepository?.load() else {
            return nil
        }
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        guard let plan = CalendarEventTogglePolicyUseCase.pillDisableConfirmationPlan(
            selectedDate: selectedDate,
            pillDates: pillDates,
            settings: settings,
            calendar: .current
        ) else { return nil }
        return PillDisableConfirmationContext(
            remainingCount: plan.remainingCount,
            todayOnlyDeleteDates: plan.todayOnlyDeleteDates,
            datesToDeleteFromSelected: plan.stopCycleDeleteDates
        )
    }
    
    func deletePillEvents(on dates: [Date]) {
        applyMutationPlan(.init(deletions: [CalendarEventMutation(type: .pill, dates: dates)]))
        let keepingMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
        recomputeLoadedMonths(keepingMonth: keepingMonth)
    }
    
    private func existingEventDatesByType() -> [EventType: Set<Date>] {
        let supportedTypes: [EventType] = [.period, .pill, .love, .ovulation, .fertile, .delayed]
        return Dictionary(uniqueKeysWithValues: supportedTypes.map { type in
            let dates = Set(eventRepository.events(of: type).map { $0.date.startOfDay })
            return (type, dates)
        })
    }
    
    private func applyMutationPlan(_ plan: CalendarEventMutationPlan) {
        for mutation in plan.deletions {
            for date in mutation.dates.map(\.startOfDay) {
                eventRepository.delete(type: mutation.type, on: date)
            }
        }
        
        for mutation in plan.additions {
            for date in mutation.dates.map(\.startOfDay) {
                let alreadyExists = eventRepository.events(of: mutation.type).contains { $0.date.startOfDay == date }
                guard alreadyExists == false else { continue }
                eventRepository.save(UserEvent(id: .init(), date: date, type: mutation.type))
            }
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
            allEvents: eventRepository.allEvents(),
            buildContext: { [weak self] bounds, userEvents in
                guard let self else {
                    return MonthComputationContext(
                        eventsByDay: [:],
                        pillDates: [],
                        pillSequenceByDate: [:],
                        predictedEventsByDay: [:],
                        predictedPeriodDates: []
                    )
                }
                return self.buildMonthComputationContext(bounds: bounds, userEvents: userEvents)
            },
            makeMonthInfo: { [weak self] month, userEvents, context in
                guard let self else {
                    return MonthInfo(
                        monthDate: month.startOfMonth,
                        days: [],
                        periodRanges: [],
                        predictedPeriodRanges: [],
                        predictedPeriodDates: [],
                        delayedRanges: [],
                        fertileRanges: [],
                        ovulationRanges: []
                    )
                }
                return self.makeMonthInfo(for: month, userEvents: userEvents, context: context)
            }
        )
        months = result.months
        currentIndex = result.currentIndex
    }
    
    private func buildMonthComputationContext(
        bounds: (start: Date, endExclusive: Date),
        userEvents: [UserEvent]
    ) -> MonthComputationContext {
        let settings = settingsRepository?.load() ?? .init()
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let allPeriodEvents = eventRepository.events(of: .period)
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
        let monthStart = month.startOfMonth
        let actualPeriodDates = Set(userEvents.filter { $0.type == .period }.map { $0.date.startOfDay })
        let result = buildDayInfos(for: monthStart, context: context)
        let days: [DayInfo] = result.days
        let predictedPeriodDates: Set<Date> = result.predictedPeriodDates
        
        let periodRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            actualPeriodDates.contains(day.date.startOfDay)
        }
        let predictedPeriodRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            predictedPeriodDates.contains(day.date.startOfDay)
        }
        let delayedRanges: [CalendarRangeInfo] = []
        let fertileRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            day.events.contains { $0.type == .fertile }
        }
        let rawOvulationRanges: [CalendarRangeInfo] = buildStyledRangesSplittingByWeeks(days: days, monthDate: monthStart) { day in
            day.events.contains { $0.type == .ovulation }
        }
        let ovulationRanges: [CalendarRangeInfo] = rawOvulationRanges.map { ovulation in
            let ovulationDate = ovulation.range.start.startOfDay
            guard let fertileOpacity = fertileOpacity(containing: ovulationDate, fertileRanges: fertileRanges) else {
                return ovulation
            }
            return CalendarRangeInfo(range: ovulation.range, opacity: fertileOpacity)
        }
        
        return MonthInfo(
            monthDate: monthStart,
            days: days,
            periodRanges: periodRanges,
            predictedPeriodRanges: predictedPeriodRanges,
            predictedPeriodDates: predictedPeriodDates,
            delayedRanges: delayedRanges,
            fertileRanges: fertileRanges,
            ovulationRanges: ovulationRanges
        )
    }
    
    private func buildDayInfos(
        for month: Date,
        context: MonthComputationContext
    ) -> (days: [DayInfo], predictedPeriodDates: Set<Date>) {
        let gridStart = month.startOfCalendarGrid()
        let gridEndExclusive = month.endOfCalendarGridExclusiveStart()
        
        var days: [DayInfo] = Date.dates(from: gridStart, toExclusive: gridEndExclusive).map { DayInfo(date: $0) }
        
        for i in days.indices {
            let key = days[i].date.startOfDay
            let dayEvents: [DayEvent] = context.eventsByDay[key] ?? []
            days[i].events = dayEvents
        }
        
        let predictedPeriodDates = Set(
            context.predictedPeriodDates.filter { $0 >= gridStart && $0 < gridEndExclusive }
        )
        if !context.predictedEventsByDay.isEmpty {
            for i in days.indices {
                let key = days[i].date.startOfDay
                guard key >= gridStart && key < gridEndExclusive,
                      let predicted = context.predictedEventsByDay[key] else { continue }
                for type in predicted where !days[i].events.contains(where: { $0.type == type }) {
                    days[i].events.append(DayEvent(type: type))
                }
            }
        }
        
        for i in days.indices {
            let dayDate = days[i].date.startOfDay
            guard context.pillDates.contains(dayDate) else {
                days[i].pillSequence = nil
                continue
            }
            days[i].pillSequence = context.pillSequenceByDate[dayDate]
        }
        
        return (days, predictedPeriodDates)
    }
    
    private func buildStyledRangesSplittingByWeeks(
        days: [DayInfo],
        monthDate: Date,
        hasEvent: (DayInfo) -> Bool,
        columns: Int = 7
    ) -> [CalendarRangeInfo] {
        var ranges: [CalendarRangeInfo] = []
        var idx = 0
        
        while idx < days.count {
            guard hasEvent(days[idx]) else {
                idx += 1
                continue
            }
            
            let runStartIndex = idx
            var runEndIndex = idx
            while runEndIndex + 1 < days.count && hasEvent(days[runEndIndex + 1]) {
                runEndIndex += 1
            }
            
            let runOpacity = opacityForRun(
                runStartDate: days[runStartIndex].date,
                runEndDate: days[runEndIndex].date,
                monthDate: monthDate
            )
            
            var segmentStartIndex = runStartIndex
            while segmentStartIndex <= runEndIndex {
                let rowEndIndex = ((segmentStartIndex / columns) * columns) + (columns - 1)
                let segmentEndIndex = min(runEndIndex, rowEndIndex)
                ranges.append(
                    CalendarRangeInfo(
                        range: DateInterval(start: days[segmentStartIndex].date, end: days[segmentEndIndex].date),
                        opacity: runOpacity
                    )
                )
                segmentStartIndex = segmentEndIndex + 1
            }
            
            idx = runEndIndex + 1
        }
        
        return ranges
    }
    
    private func opacityForRun(runStartDate: Date, runEndDate: Date, monthDate: Date) -> Double {
        let isOutsideCurrentMonth =
        !runStartDate.isInSameMonth(as: monthDate) &&
        !runEndDate.isInSameMonth(as: monthDate)
        return isOutsideCurrentMonth ? 0.3 : 1
    }
    
    private func fertileOpacity(containing date: Date, fertileRanges: [CalendarRangeInfo]) -> Double? {
        fertileRanges.first {
            date >= $0.range.start.startOfDay && date <= $0.range.end.startOfDay
        }?.opacity
    }
    
    private var isPillEnabled: Bool {
        settingsRepository?.load().pill.pillEnabled == true
    }
}

// DayInfoCard
extension CalendarViewModel {
    func primaryStatus(for date: Date) -> CalendarPrimaryStatus {
        let settings = settingsRepository?.load() ?? .init()
        let periodDates = eventRepository.events(of: .period).map(\.date)
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let snapshot = DayInfoCardStatusUseCase.primaryStatus(
            for: date,
            today: Date(),
            periodDates: periodDates,
            pillDates: pillDates,
            settings: settings,
            calendar: .current
        )
        return mapPrimaryStatus(snapshot)
    }
    
    func secondaryStatus(for date: Date) -> CalendarSecondaryStatus {
        let settings = settingsRepository?.load() ?? .init()
        let pillDates = Set(eventRepository.events(of: .pill).map { $0.date.startOfDay })
        let dayEvents = months
            .flatMap(\.days)
            .first(where: { $0.date.isSameDay(as: date) })?
            .events
        
        let snapshot = DayInfoCardStatusUseCase.secondaryStatus(
            for: date,
            allEventsEmpty: eventRepository.allEvents().isEmpty,
            isPillEnabled: isPillEnabled,
            dayEvents: dayEvents,
            pillDates: pillDates,
            settings: settings,
            calendar: .current
        )
        return mapSecondaryStatus(snapshot)
    }
    
    private func actualPeriodSummaries() -> [PeriodSummary] {
        let events = eventRepository.events(of: .period)
        return PeriodSummaryBuilder.build(from: events.map { $0.date })
    }
    
    private func predictedPeriodLengthDaysFromCurrentData() -> Int {
        let settings = settingsRepository?.load() ?? .init()
        return PeriodForecastCalculator.predictedPeriodLengthDays(
            settings: settings,
            periodSummaries: actualPeriodSummaries()
        )
    }
    
    private func manualCycleAverages(for settings: UserSettings) -> (cycleDays: Int?, periodDays: Int?) {
        let periodSettings = settings.period
        guard periodSettings.autoCyclePredictionEnabled == false else {
            return (nil, nil)
        }
        return (periodSettings.averageCycleDays, periodSettings.averagePeriodDays)
    }
    
    private func mapPrimaryStatus(_ snapshot: DayInfoCardPrimarySnapshot) -> CalendarPrimaryStatus {
        switch snapshot {
        case .countdown(let days):
            return .countdown(days: days)
        case .ongoing(let day):
            return .ongoing(day: day)
        case .bDay:
            return .bDay
        case .delayed(let days):
            return .delayed(days: days)
        case .unknown:
            return .unknown
        }
    }
    
    private func mapSecondaryStatus(_ snapshot: DayInfoCardSecondarySnapshot) -> CalendarSecondaryStatus {
        switch snapshot {
        case .pill(let day, let total):
            return .pill(day: day, total: total)
        case .pillBreak(let day, let total):
            return .pillBreak(day: day, total: total)
        case .ovulation:
            return .ovulation
        case .fertile:
            return .fertile
        case .notFertile:
            return .notFertile
        case .unknown:
            return .unknown
        }
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
