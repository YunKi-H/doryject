//
//  CalendarDisplayEventRepositoryTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarDisplayEventRepositoryTests {
    private let calendar = Calendar.current

    @Test
    func sharedEventsReplaceLocalDisplayAndBlockMutations() throws {
        let localDate = makeDate(2026, 7, 1)
        let sharedDate = makeDate(2026, 7, 8)
        let localRepository = RecordingDisplayEventRepository(
            events: [UserEvent(date: localDate, type: .love, calendar: calendar)]
        )
        let repository = CalendarDisplayEventRepository(
            localRepository: localRepository,
            runtimeStore: makeRuntimeStore(),
            calendar: calendar
        )
        let sharedDay = CalendarDay(date: sharedDate, calendar: calendar)
        let sharedEventID = UUID()

        repository.prepareSharedCalendar(
            connectionID: "shared-calendar"
        )
        repository.displaySharedCalendar(
            snapshot: SharedCalendarSnapshot(
                events: [
                SharedCalendarEvent(
                    id: sharedEventID,
                    day: sharedDay,
                    type: .period
                )
                ],
                pillCycles: []
            )
        )
        let saveResult = repository.save(
            UserEvent(date: sharedDate, type: .pill, calendar: calendar)
        )
        let deleteResult = repository.delete(
            type: .period,
            on: sharedDate
        )

        let displayedEvent = try #require(repository.allEvents().first)
        #expect(repository.isDisplayingSharedCalendar)
        #expect(repository.allEvents().count == 1)
        #expect(displayedEvent.id == sharedEventID)
        #expect(displayedEvent.type == .period)
        #expect(displayedEvent.calendarDay == sharedDay)
        #expect(localRepository.saveCallCount == 0)
        #expect(localRepository.deleteCallCount == 0)
        #expect(saveResult.succeeded == false)
        #expect(deleteResult.succeeded == false)
    }

    @Test
    func returningToLocalCalendarRestoresLocalEventsAndMutations() {
        let localDate = makeDate(2026, 7, 1)
        let localRepository = RecordingDisplayEventRepository(
            events: [UserEvent(date: localDate, type: .love, calendar: calendar)]
        )
        let repository = CalendarDisplayEventRepository(
            localRepository: localRepository,
            runtimeStore: makeRuntimeStore(),
            calendar: calendar
        )
        repository.prepareSharedCalendar(
            connectionID: "shared-calendar"
        )
        repository.displaySharedCalendar(
            snapshot: SharedCalendarSnapshot(events: [], pillCycles: [])
        )

        repository.displayLocalCalendar()
        let saveResult = repository.save(
            UserEvent(date: localDate, type: .pill, calendar: calendar)
        )

        #expect(repository.isDisplayingSharedCalendar == false)
        #expect(repository.allEvents().map(\.type) == [.love])
        #expect(localRepository.saveCallCount == 1)
        #expect(saveResult.succeeded)
    }

    @Test
    func cachedViewerStateKeepsSharedCalendarAndOwnerSettingsOffline() {
        let runtimeStore = makeRuntimeStore()
        let sharedDate = makeDate(2026, 7, 8)
        var pillSettings = PillSettings()
        pillSettings.pillEnabled = true
        pillSettings.pillCount = 24
        pillSettings.pillBreakDuration = 4
        let computationSettings = SharedCalendarComputationSettings(
            period: PeriodSettings(
                autoCyclePredictionEnabled: true,
                averageCycleDays: 31,
                averagePeriodDays: 6
            ),
            pill: pillSettings
        )
        let initialRepository = CalendarDisplayEventRepository(
            localRepository: RecordingDisplayEventRepository(events: []),
            runtimeStore: runtimeStore,
            calendar: calendar
        )
        initialRepository.prepareSharedCalendar(
            connectionID: "shared-calendar"
        )
        initialRepository.displaySharedCalendar(
            snapshot: SharedCalendarSnapshot(
                events: [
                SharedCalendarEvent(
                    id: UUID(),
                    day: CalendarDay(date: sharedDate, calendar: calendar),
                    type: .period
                )
                ],
                pillCycles: [],
                computationSettings: computationSettings
            )
        )

        let restoredRepository = CalendarDisplayEventRepository(
            localRepository: RecordingDisplayEventRepository(
                events: [UserEvent(date: sharedDate, type: .love)]
            ),
            runtimeStore: runtimeStore,
            calendar: calendar
        )
        let restoredSettings = restoredRepository.load()

        #expect(restoredRepository.isDisplayingSharedCalendar)
        #expect(restoredRepository.allEvents().map(\.type) == [.period])
        #expect(restoredSettings.period.averageCycleDays == 31)
        #expect(restoredSettings.period.averagePeriodDays == 6)
        #expect(restoredSettings.pill.pillCount == 24)
        #expect(restoredSettings.pill.pillBreakDuration == 4)
    }

    @Test
    func sharedPillCycleMetadataRestoresHistoricalCycleSettings() throws {
        let runtimeStore = makeRuntimeStore()
        let repository = CalendarDisplayEventRepository(
            localRepository: RecordingDisplayEventRepository(events: []),
            runtimeStore: runtimeStore,
            calendar: calendar
        )
        let cycleID = UUID()
        let intakeDate = makeDate(2026, 7, 8)
        let intakeDay = CalendarDay(date: intakeDate, calendar: calendar)

        repository.prepareSharedCalendar(
            connectionID: "shared-calendar"
        )
        repository.displaySharedCalendar(
            snapshot: SharedCalendarSnapshot(
                events: [
                    SharedCalendarEvent(
                        id: UUID(),
                        day: intakeDay,
                        type: .pill,
                        pillCycleID: cycleID
                    )
                ],
                pillCycles: [
                    SharedPillCycleMetadata(
                        id: cycleID,
                        startDay: intakeDay,
                        plannedPillCount: 24,
                        breakDays: 4,
                        autoRecordEnabled: true,
                        status: .completed
                    )
                ]
            )
        )

        let cycle = try #require(repository.pillCycles().first)
        #expect(cycle.id == cycleID)
        #expect(cycle.intakeDates == [intakeDate])
        #expect(cycle.plannedPillCount == 24)
        #expect(cycle.breakDays == 4)
        #expect(cycle.autoRecordEnabled == true)
        #expect(cycle.status == .completed)
    }

    @Test
    func committedSnapshotReplacesEventsAndSettingsTogether() {
        let runtimeStore = makeRuntimeStore()
        let repository = CalendarDisplayEventRepository(
            localRepository: RecordingDisplayEventRepository(events: []),
            runtimeStore: runtimeStore,
            calendar: calendar
        )
        let committedSettings = SharedCalendarComputationSettings(
            period: PeriodSettings(averageCycleDays: 31),
            pill: PillSettings(pillEnabled: true, pillCount: 24)
        )
        let sharedDate = makeDate(2026, 7, 8)

        repository.prepareSharedCalendar(
            connectionID: "shared-calendar"
        )
        repository.displaySharedCalendar(
            snapshot: SharedCalendarSnapshot(
                events: [
                    SharedCalendarEvent(
                        id: UUID(),
                        day: CalendarDay(
                            date: sharedDate,
                            calendar: calendar
                        ),
                        type: .period
                    )
                ],
                pillCycles: [],
                computationSettings: committedSettings,
                publicationVersion: "version-2"
            )
        )

        #expect(repository.allEvents().map(\.type) == [.period])
        #expect(repository.load().period.averageCycleDays == 31)
        #expect(repository.load().pill.pillEnabled)
        #expect(repository.load().pill.pillCount == 24)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }

    private func makeRuntimeStore() -> CalendarSharingRuntimeStore {
        let suiteName = "CalendarDisplayEventRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return CalendarSharingRuntimeStore(defaults: defaults)
    }
}

private final class RecordingDisplayEventRepository: EventRepository {
    private let events: [UserEvent]
    private(set) var saveCallCount = 0
    private(set) var deleteCallCount = 0

    init(events: [UserEvent]) {
        self.events = events
    }

    func save(_ event: UserEvent) -> EventMutationResult {
        saveCallCount += 1
        return .changed
    }

    func delete(id: UUID) -> EventMutationResult {
        deleteCallCount += 1
        return .changed
    }

    func delete(type: EventType, on: Date) -> EventMutationResult {
        deleteCallCount += 1
        return .changed
    }

    func replace(type: EventType, on dates: Set<Date>) -> EventMutationResult {
        .unchanged
    }

    func allEvents() -> [UserEvent] {
        events
    }

    func events(forMonth month: Date) -> [UserEvent] {
        events
    }

    func events(of type: EventType) -> [UserEvent] {
        events.filter { $0.type == type }
    }
}
