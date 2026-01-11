//
//  NoopAppleCalendarClient.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

final class NoopAppleCalendarClient: AppleCalendarClient {
    func requestAccess() async -> Bool {
        true
    }

    func createOrFetchCalendar(name: String, existingIdentifier: String?) -> String? {
        existingIdentifier ?? UUID().uuidString
    }

    func removeCalendar(identifier: String) {
    }

    func upsertEvent(
        event: UserEvent,
        calendarIdentifier: String,
        title: String,
        existingEventIdentifier: String?,
        dateRange: DateInterval?
    ) -> String? {
        existingEventIdentifier ?? UUID().uuidString
    }

    func deleteEvent(identifier: String) {
    }
}
