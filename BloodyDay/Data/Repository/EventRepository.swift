//
//  EventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 10/21/25.
//

import Foundation

protocol EventRepository {
    func save(_ event: UserEvent)
    func delete(id: UUID)
    func delete(type: EventType, on: Date)
    func replace(type: EventType, on dates: Set<Date>)
    func allEvents() -> [UserEvent]
    func events(forMonth month: Date) -> [UserEvent]
    func events(of type: EventType) -> [UserEvent]
}

final class MockEventRepository: EventRepository {
    func save(_ event: UserEvent) {
        
    }
    
    func delete(id: UUID) {
        
    }
    
    func delete(type: EventType, on: Date) {
        
    }
    
    func replace(type: EventType, on dates: Set<Date>) {
        
    }
    
    func allEvents() -> [UserEvent] {
        []
    }
    
    func events(forMonth month: Date) -> [UserEvent] {
        []
    }
    
    func events(of type: EventType) -> [UserEvent] {
        []
    }
}
