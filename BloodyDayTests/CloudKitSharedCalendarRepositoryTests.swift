//
//  CloudKitSharedCalendarRepositoryTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

@MainActor
struct CloudKitSharedCalendarRepositoryTests {
    @Test
    func refreshMergesLocalDisplayNameAndReplacesEvents() async {
        let calendarID = "shared-calendar"
        let existingCalendar = makeCalendar(
            id: calendarID,
            remoteTitle: "이전 이름",
            localDisplayName: "민지"
        )
        let incomingCalendar = makeCalendar(
            id: calendarID,
            remoteTitle: "새 이름",
            localDisplayName: nil
        )
        let incomingEvent = makeEvent(id: "event-1", calendarId: calendarID, type: .period)
        let localRepository = LocalSharedCalendarRepository(calendars: [existingCalendar])
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.sharedSnapshot = SharedCalendarSnapshot(
            calendars: [incomingCalendar],
            eventsByCalendarId: [calendarID: [incomingEvent]]
        )
        let repository = CloudKitSharedCalendarRepository(
            cloudSharingService: cloudSharingService,
            localRepository: localRepository
        )

        await repository.refresh()

        let refreshedCalendar = repository.calendar(id: calendarID)
        #expect(refreshedCalendar?.remoteTitle == "새 이름")
        #expect(refreshedCalendar?.localDisplayName == "민지")
        #expect(repository.events(calendarId: calendarID) == [incomingEvent])
    }

    @Test
    func refreshRemovesLocalCalendarMissingFromSnapshot() async {
        let keptCalendar = makeCalendar(id: "kept")
        let removedCalendar = makeCalendar(id: "removed")
        let localRepository = LocalSharedCalendarRepository(
            calendars: [keptCalendar, removedCalendar],
            eventsByCalendarId: [
                keptCalendar.id: [makeEvent(id: "kept-event", calendarId: keptCalendar.id, type: .pill)],
                removedCalendar.id: [makeEvent(id: "removed-event", calendarId: removedCalendar.id, type: .love)]
            ]
        )
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.sharedSnapshot = SharedCalendarSnapshot(
            calendars: [keptCalendar],
            eventsByCalendarId: [keptCalendar.id: [makeEvent(id: "new-kept-event", calendarId: keptCalendar.id, type: .period)]]
        )
        let repository = CloudKitSharedCalendarRepository(
            cloudSharingService: cloudSharingService,
            localRepository: localRepository
        )

        await repository.refresh()

        #expect(repository.calendar(id: keptCalendar.id) != nil)
        #expect(repository.calendar(id: removedCalendar.id) == nil)
        #expect(repository.events(calendarId: removedCalendar.id).isEmpty)
        #expect(repository.events(calendarId: keptCalendar.id).map(\.id) == ["new-kept-event"])
    }

    private func makeCalendar(
        id: String,
        remoteTitle: String = "공유 캘린더",
        localDisplayName: String? = nil
    ) -> SharedCalendar {
        SharedCalendar(
            id: id,
            remoteTitle: remoteTitle,
            localDisplayName: localDisplayName,
            sharedEventTypes: .all,
            acceptedAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeEvent(id: String, calendarId: String, type: EventType) -> SharedCalendarEvent {
        SharedCalendarEvent(
            id: id,
            calendarId: calendarId,
            type: type,
            date: Date().startOfDay,
            updatedAt: Date()
        )
    }
}
