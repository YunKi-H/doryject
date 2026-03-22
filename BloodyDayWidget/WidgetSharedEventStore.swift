//
//  WidgetSharedEventStore.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import Foundation
import SwiftData

enum WidgetSharedEventStore {
    static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    private static let storeFileName = "BloodyDay.sqlite"
    private static let sharedContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: UserEvent.self,
                configurations: ModelConfiguration(url: storeURL())
            )
        } catch {
            fatalError("Failed to create widget shared model container: \(error)")
        }
    }()
    
    static func toggle(_ type: EventType, on date: Date, calendar: Calendar = .current) -> Bool {
        let context = ModelContext(sharedContainer)
        let target = calendar.startOfDay(for: date)
        let key = UserEvent.makeUniqueKey(date: target, type: type, calendar: calendar)
        let descriptor = FetchDescriptor<UserEvent>(
            predicate: #Predicate<UserEvent> { $0.uniqueKey == key }
        )
        
        do {
            let existing = try context.fetch(descriptor)
            if let event = existing.first {
                context.delete(event)
                try context.save()
                return false
            } else {
                context.insert(UserEvent(date: target, type: type, calendar: calendar))
                try context.save()
                return true
            }
        } catch {
            assertionFailure("Widget event toggle failed: \(error)")
            return false
        }
    }
    
    static func allEvents() -> [UserEvent] {
        let context = ModelContext(sharedContainer)
        let descriptor = FetchDescriptor<UserEvent>(
            sortBy: [SortDescriptor(\UserEvent.date, order: .forward)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            assertionFailure("Widget event fetch failed: \(error)")
            return []
        }
    }
    
    private static func storeURL() -> URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return groupURL.appendingPathComponent(storeFileName)
        }
        
        let fallbackDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(
            at: fallbackDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return fallbackDirectory.appendingPathComponent(storeFileName)
    }
}
