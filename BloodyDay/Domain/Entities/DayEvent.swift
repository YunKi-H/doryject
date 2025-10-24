//
//  DayEvent.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import Foundation

struct DayEvent: Identifiable, Hashable {
    let id: UUID = .init()
    let type: EventType
}
