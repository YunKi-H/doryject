//
//  SharedCalendarEventSyncing.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

protocol SharedCalendarEventSyncing {
    func syncOwnedEvents(
        _ events: [UserEvent],
        pillCycles: [PillCycleInfo],
        connection: CalendarConnection,
        computationSettings: SharedCalendarComputationSettings
    ) async throws
}

protocol SharedCalendarSyncScheduling: AnyObject {
    func schedule()
}
