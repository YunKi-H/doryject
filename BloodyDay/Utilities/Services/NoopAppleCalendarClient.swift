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

    func syncEvents(events: [UserEvent], calendarIdentifier: String, title: String) {
    }
}
