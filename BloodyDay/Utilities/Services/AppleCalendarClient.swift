//
//  AppleCalendarClient.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

protocol AppleCalendarClient {
    func requestAccess() async -> Bool
    func createOrFetchCalendar(name: String, existingIdentifier: String?) -> String?
    func removeCalendar(identifier: String)
    func syncEvents(
        events: [UserEvent],
        calendarIdentifier: String,
        title: String
    )
}
