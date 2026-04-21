//
//  CloudKitSharedCalendarRepository.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

protocol SharedCalendarReloading: AnyObject {
    @MainActor
    func refresh() async
}

@MainActor
final class CloudKitSharedCalendarRepository: SharedCalendarRepository, SharedCalendarManaging, SharedCalendarReloading {
    private let cloudSharingService: CloudSharingService
    private let localRepository: LocalSharedCalendarRepository
    
    init(
        cloudSharingService: CloudSharingService,
        localRepository: LocalSharedCalendarRepository = .init()
    ) {
        self.cloudSharingService = cloudSharingService
        self.localRepository = localRepository
    }
    
    func calendars() -> [SharedCalendar] {
        localRepository.calendars()
    }
    
    func calendar(id: String) -> SharedCalendar? {
        localRepository.calendar(id: id)
    }
    
    func events(calendarId: String) -> [SharedCalendarEvent] {
        localRepository.events(calendarId: calendarId)
    }
    
    func updateLocalDisplayName(calendarId: String, name: String?) {
        localRepository.updateLocalDisplayName(calendarId: calendarId, name: name)
    }
    
    func removeLocalCalendar(calendarId: String) {
        localRepository.removeLocalCalendar(calendarId: calendarId)
    }
    
    func refresh() async {
        let existingCalendars = localRepository.calendars()
        do {
            let snapshot = try await cloudSharingService.fetchSharedSnapshot()
            localRepository.replaceCalendars(
                mergeLocalDisplayNames(
                    from: existingCalendars,
                    into: snapshot.calendars
                )
            )
            for (calendarId, events) in snapshot.eventsByCalendarId {
                localRepository.replaceEvents(calendarId: calendarId, events: events)
            }
            let snapshotCalendarIDs = Set(snapshot.calendars.map(\.id))
            for existingID in Set(existingCalendars.map(\.id)).subtracting(snapshotCalendarIDs) {
                localRepository.removeLocalCalendar(calendarId: existingID)
            }
        } catch {
        }
    }
    
    private func mergeLocalDisplayNames(
        from existingCalendars: [SharedCalendar],
        into incomingCalendars: [SharedCalendar]
    ) -> [SharedCalendar] {
        let existingNames = Dictionary(uniqueKeysWithValues: existingCalendars.map { ($0.id, $0.localDisplayName) })
        return incomingCalendars.map { calendar in
            var calendar = calendar
            if let localDisplayName = existingNames[calendar.id], let localDisplayName {
                calendar.localDisplayName = localDisplayName
            }
            return calendar
        }
    }
}
