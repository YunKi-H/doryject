//
//  UserEventDateTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Foundation
import SwiftData
import Testing
@testable import BloodyDay

struct UserEventDateTests {
    @Test
    func resolvedDatePreservesCalendarDayAcrossTimeZones() {
        let seoul = calendar(timeZoneIdentifier: "Asia/Seoul")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let recordedDate = seoul.date(
            from: DateComponents(year: 2026, month: 7, day: 24)
        )!
        let event = UserEvent(
            date: recordedDate,
            type: .period,
            calendar: seoul
        )

        let absoluteComponentsInLosAngeles = losAngeles.dateComponents(
            [.year, .month, .day],
            from: event.date
        )
        #expect(absoluteComponentsInLosAngeles.day == 23)

        let resolved = event.resolvedDate(calendar: losAngeles)
        let resolvedComponents = losAngeles.dateComponents(
            [.year, .month, .day],
            from: resolved
        )

        #expect(resolvedComponents.year == 2026)
        #expect(resolvedComponents.month == 7)
        #expect(resolvedComponents.day == 24)
        #expect(event.uniqueKey == "20260724|\(EventType.period.rawValue)")
    }

    @Test
    func normalizeDateRebasesStoredTimestampWithoutChangingItsDayIdentity() {
        let seoul = calendar(timeZoneIdentifier: "Asia/Seoul")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let event = UserEvent(
            date: seoul.date(
                from: DateComponents(year: 2026, month: 7, day: 24)
            )!,
            type: .pill,
            calendar: seoul
        )

        let changed = event.normalizeDate(calendar: losAngeles)
        let components = losAngeles.dateComponents(
            [.year, .month, .day],
            from: event.date
        )

        #expect(changed)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 24)
        #expect(event.uniqueKey == "20260724|\(EventType.pill.rawValue)")
    }

    @Test
    func repositoryMonthQueryUsesCanonicalDayAfterTimeZoneChange() throws {
        let seoul = calendar(timeZoneIdentifier: "Asia/Seoul")
        let losAngeles = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserEvent.self,
            PillCycle.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let event = UserEvent(
            date: seoul.date(
                from: DateComponents(year: 2026, month: 7, day: 1)
            )!,
            type: .period,
            calendar: seoul
        )
        context.insert(event)
        try context.save()

        let repository = SwiftDataEventRepository(
            context: context,
            calendar: losAngeles,
            settingsRepository: UserEventDateSettingsRepository()
        )
        let july = losAngeles.date(
            from: DateComponents(year: 2026, month: 7, day: 15)
        )!
        let events = repository.events(forMonth: july)
        let components = events.first.map {
            losAngeles.dateComponents([.year, .month, .day], from: $0.date)
        }

        #expect(events.count == 1)
        #expect(components?.year == 2026)
        #expect(components?.month == 7)
        #expect(components?.day == 1)
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }
}

private final class UserEventDateSettingsRepository: SettingsRepository {
    func load() -> UserSettings {
        .init()
    }

    func save(_ settings: UserSettings) {}
}
