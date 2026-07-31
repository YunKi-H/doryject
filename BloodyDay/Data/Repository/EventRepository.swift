//
//  EventRepository.swift
//  BloodyDay
//
//  Created by Yunki on 10/21/25.
//

import Foundation

enum EventMutationResult {
    case changed
    case unchanged
    case failed(Error)

    var succeeded: Bool {
        if case .failed = self { return false }
        return true
    }
}

enum EventRepositoryMutationError: LocalizedError {
    case readOnlyCalendar

    var errorDescription: String? {
        switch self {
        case .readOnlyCalendar:
            return "공유받은 캘린더에서는 이벤트를 변경할 수 없어요."
        }
    }
}

protocol EventReading {
    func events(of type: EventType) -> [UserEvent]
    func pillCycles() -> [PillCycleInfo]
}

extension EventReading {
    func pillCycles() -> [PillCycleInfo] {
        []
    }
}

protocol EventRepository: EventReading {
    @discardableResult
    func save(_ event: UserEvent) -> EventMutationResult
    @discardableResult
    func delete(id: UUID) -> EventMutationResult
    @discardableResult
    func delete(type: EventType, on: Date) -> EventMutationResult
    @discardableResult
    func replace(type: EventType, on dates: Set<Date>) -> EventMutationResult
    func allEvents() -> [UserEvent]
    func events(forMonth month: Date) -> [UserEvent]
}

final class MockEventRepository: EventRepository {
    func save(_ event: UserEvent) -> EventMutationResult {
        .unchanged
    }
    
    func delete(id: UUID) -> EventMutationResult {
        .unchanged
    }
    
    func delete(type: EventType, on: Date) -> EventMutationResult {
        .unchanged
    }
    
    func replace(type: EventType, on dates: Set<Date>) -> EventMutationResult {
        .unchanged
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

    func pillCycles() -> [PillCycleInfo] {
        []
    }
}
