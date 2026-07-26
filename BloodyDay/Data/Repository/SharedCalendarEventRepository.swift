//
//  SharedCalendarEventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

protocol SharedCalendarEventRepository {
    func observeSnapshot(
        connectionID: String,
        onChange: @escaping (Result<SharedCalendarSnapshot, Error>) -> Void
    ) -> CalendarConnectionObservation
}
