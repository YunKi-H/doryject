//
//  SharedCalendarEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

protocol SharedCalendarEventRepository {
    func observeEvents(
        connectionID: String,
        onChange: @escaping (Result<[SharedCalendarEvent], Error>) -> Void
    ) -> CalendarConnectionObservation
}
