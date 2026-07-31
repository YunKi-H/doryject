//
//  FirestoreSharedCalendarSnapshotObservationTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/31/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct FirestoreSharedCalendarSnapshotObservationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func emitsOnlyAfterEveryDocumentForCommittedVersionArrives() throws {
        let oldEvent = UserEvent(
            date: makeDate(2026, 7, 7),
            type: .love,
            calendar: calendar
        )
        let newEvent = UserEvent(
            date: makeDate(2026, 7, 8),
            type: .period,
            calendar: calendar
        )
        let settings = makeSettings(cycleDays: 31)
        var snapshots: [SharedCalendarSnapshot] = []
        let observation = FirestoreSharedCalendarSnapshotObservation {
            if case .success(let snapshot) = $0 {
                snapshots.append(snapshot)
            }
        }

        observation.update(
            publication: FirestoreSharedCalendarPublicationMetadata(
                version: "new",
                eventCount: 1,
                pillCycleCount: 0,
                computationSettings: settings
            ),
            legacyComputationSettings: nil
        )
        observation.update(eventDocuments: [
            "old": eventData(oldEvent, version: "old")
        ])
        observation.update(pillCycleDocuments: [:])

        #expect(snapshots.isEmpty)

        observation.update(eventDocuments: [
            "old": eventData(oldEvent, version: "old"),
            "new": eventData(newEvent, version: "new")
        ])

        let snapshot = try #require(snapshots.last)
        #expect(snapshots.count == 1)
        #expect(snapshot.events.map(\.id) == [newEvent.id])
        #expect(snapshot.computationSettings == settings)
        #expect(snapshot.publicationVersion == "new")
    }

    @Test
    func ignoresDraftVersionUntilConnectionCommitsItsMetadata() throws {
        let oldEvent = UserEvent(
            date: makeDate(2026, 7, 7),
            type: .love,
            calendar: calendar
        )
        let newEvent = UserEvent(
            date: makeDate(2026, 7, 8),
            type: .period,
            calendar: calendar
        )
        let oldSettings = makeSettings(cycleDays: 28)
        let newSettings = makeSettings(cycleDays: 31)
        var snapshots: [SharedCalendarSnapshot] = []
        let observation = FirestoreSharedCalendarSnapshotObservation {
            if case .success(let snapshot) = $0 {
                snapshots.append(snapshot)
            }
        }

        observation.update(
            publication: FirestoreSharedCalendarPublicationMetadata(
                version: "old",
                eventCount: 1,
                pillCycleCount: 0,
                computationSettings: oldSettings
            ),
            legacyComputationSettings: nil
        )
        observation.update(eventDocuments: [
            "old": eventData(oldEvent, version: "old")
        ])
        observation.update(pillCycleDocuments: [:])
        observation.update(eventDocuments: [
            "old": eventData(oldEvent, version: "old"),
            "new": eventData(newEvent, version: "new")
        ])

        #expect(snapshots.count == 1)
        #expect(snapshots.last?.events.map(\.id) == [oldEvent.id])
        #expect(snapshots.last?.computationSettings == oldSettings)

        observation.update(
            publication: FirestoreSharedCalendarPublicationMetadata(
                version: "new",
                eventCount: 1,
                pillCycleCount: 0,
                computationSettings: newSettings
            ),
            legacyComputationSettings: nil
        )

        #expect(snapshots.count == 2)
        #expect(snapshots.last?.events.map(\.id) == [newEvent.id])
        #expect(snapshots.last?.computationSettings == newSettings)
    }

    private func eventData(
        _ event: UserEvent,
        version: String
    ) -> [String: Any] {
        FirestoreCalendarSharingMapper.sharedEventData(
            event,
            ownerID: "owner",
            publicationVersion: version,
            calendar: calendar
        )
    }

    private func makeSettings(
        cycleDays: Int
    ) -> SharedCalendarComputationSettings {
        SharedCalendarComputationSettings(
            period: PeriodSettings(averageCycleDays: cycleDays),
            pill: PillSettings()
        )
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }
}
