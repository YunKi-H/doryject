//
//  CalendarSharingSettings.swift
//  BloodyDay
//
//  Created by Yunki on 4/22/26.
//

import Foundation

struct CalendarSharingSettings: Codable, Equatable {
    var defaultSharedEventTypes: SharedEventTypeSelection = .all
}
