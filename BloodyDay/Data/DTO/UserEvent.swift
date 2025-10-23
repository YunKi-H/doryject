//
//  UserEvent.swift
//  BloodyDay
//
//  Created by Yunki on 10/21/25.
//

import Foundation
import SwiftData

@Model
final class UserEvent {
    var id: UUID
    var date: Date
    var type: EventType
    
    init(id: UUID = .init(), date: Date, type: EventType) {
        self.id = id
        self.date = date
        self.type = type
    }
}
