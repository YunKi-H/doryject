//
//  CalendarEventTogglePolicy.swift
//  BloodyDay
//
//  Created by Yunki on 2/23/26.
//

import Foundation

struct CalendarEventMutationPlan: Equatable {
    var additions: [CalendarEventMutation] = []
    var deletions: [CalendarEventMutation] = []
    
    var isEmpty: Bool { additions.isEmpty && deletions.isEmpty }
}

struct CalendarEventMutation: Equatable {
    let type: EventType
    let dates: [Date]
}

struct PillDisableConfirmationPlan: Equatable {
    let remainingCount: Int
    let todayOnlyDeleteDates: [Date]
    let stopCycleDeleteDates: [Date]
}
