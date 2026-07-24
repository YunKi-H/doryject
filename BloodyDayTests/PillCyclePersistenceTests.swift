//
//  PillCyclePersistenceTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import SwiftData
import Testing
@testable import BloodyDay

struct PillCyclePersistenceTests {
    private let calendar = Calendar.current

    @Test
    func migrationPreservesCompletedHistoricalRunWithoutCurrentPillCount() throws {
        let context = try makeContext()
        let start = makeDate(2026, 1, 1)
        for offset in 0..<23 {
            context.insert(
                UserEvent(
                    date: addDays(start, offset),
                    type: .pill,
                    calendar: calendar
                )
            )
        }
        try context.save()

        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        PillCyclePersistence.migrateIfNeeded(
            in: context,
            settings: settings,
            today: makeDate(2026, 3, 1),
            calendar: calendar
        )

        let cycles = PillCyclePersistence.cycleInfos(in: context)
        let cycle = try #require(cycles.first)
        #expect(cycles.count == 1)
        #expect(cycle.intakeDates.count == 23)
        #expect(cycle.plannedPillCount == nil)
        #expect(cycle.breakDays == nil)
        #expect(cycle.status == .completed)
    }

    @Test
    func migrationSnapshotsCurrentSettingsOnlyForLatestActiveRun() throws {
        let context = try makeContext()
        let oldStart = makeDate(2026, 1, 1)
        let currentStart = makeDate(2026, 2, 1)
        for date in [
            oldStart,
            addDays(oldStart, 1),
            currentStart,
            addDays(currentStart, 1)
        ] {
            context.insert(UserEvent(date: date, type: .pill, calendar: calendar))
        }
        try context.save()

        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = false
        settings.pill.pillCount = 28
        settings.pill.pillBreakDuration = 4
        PillCyclePersistence.migrateIfNeeded(
            in: context,
            settings: settings,
            today: addDays(currentStart, 2),
            calendar: calendar
        )

        let cycles = PillCyclePersistence.cycleInfos(in: context)
        #expect(cycles.count == 2)
        #expect(cycles[0].plannedPillCount == nil)
        #expect(cycles[0].status == .completed)
        #expect(cycles[1].plannedPillCount == 28)
        #expect(cycles[1].breakDays == 4)
        #expect(cycles[1].autoRecordEnabled == false)
        #expect(cycles[1].status == .active)
    }

    @Test
    func assignmentStartsNewCycleAfterStoredPillCountIsReached() throws {
        let context = try makeContext()
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillCount = 2
        settings.pill.pillBreakDuration = 7
        let start = makeDate(2026, 2, 1)

        for offset in 0..<3 {
            let event = UserEvent(
                date: addDays(start, offset),
                type: .pill,
                calendar: calendar
            )
            try PillCyclePersistence.assignCycle(
                to: event,
                in: context,
                settings: settings,
                calendar: calendar
            )
            context.insert(event)
        }
        try context.save()

        let cycles = PillCyclePersistence.cycleInfos(in: context)
        #expect(cycles.count == 2)
        #expect(cycles[0].intakeDates.count == 2)
        #expect(cycles[0].status == .completed)
        #expect(cycles[1].intakeDates == [addDays(start, 2)])
        #expect(cycles[1].status == .active)
    }

    @Test
    func assignmentAfterLatestCompletedCycleStartsNewActiveCycle() throws {
        let context = try makeContext()
        let previousStart = makeDate(2026, 2, 1)
        let previousCycle = PillCycle(
            startDate: previousStart,
            plannedPillCount: nil,
            breakDays: nil,
            autoRecordEnabled: nil,
            status: .completed
        )
        context.insert(previousCycle)
        context.insert(
            UserEvent(
                date: previousStart,
                type: .pill,
                pillCycleID: previousCycle.id,
                calendar: calendar
            )
        )
        try context.save()

        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillCount = 21
        let nextEvent = UserEvent(
            date: addDays(previousStart, 1),
            type: .pill,
            calendar: calendar
        )
        try PillCyclePersistence.assignCycle(
            to: nextEvent,
            in: context,
            settings: settings,
            calendar: calendar
        )
        context.insert(nextEvent)
        try context.save()

        let cycles = PillCyclePersistence.cycleInfos(in: context)
        #expect(cycles.count == 2)
        #expect(cycles[0].status == .completed)
        #expect(cycles[1].status == .active)
        #expect(cycles[1].plannedPillCount == 21)
    }

    @Test
    func cycleInfoReadResolvesCalendarDayWithoutMutatingPersistedEvent() throws {
        let seoul = calendar(timeZoneIdentifier: "Asia/Seoul")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let context = try makeContext()
        let recordedDate = seoul.date(
            from: DateComponents(year: 2026, month: 7, day: 24)
        )!
        let cycle = PillCycle(
            startDate: recordedDate,
            plannedPillCount: 21,
            breakDays: 7,
            autoRecordEnabled: true,
            status: .active,
            calendar: seoul
        )
        let event = UserEvent(
            date: recordedDate,
            type: .pill,
            pillCycleID: cycle.id,
            calendar: seoul
        )
        context.insert(cycle)
        context.insert(event)
        try context.save()
        let persistedDate = event.date

        let cycleInfos = PillCyclePersistence.cycleInfos(
            in: context,
            calendar: losAngeles
        )
        let intakeDate = try #require(cycleInfos.first?.intakeDates.first)
        let components = losAngeles.dateComponents(
            [.year, .month, .day],
            from: intakeDate
        )

        #expect(event.date == persistedDate)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 24)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserEvent.self,
            PillCycle.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: 12)
        )!.startOfDay
    }

    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }
}
