//
//  WidgetSharedEventStore.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import Foundation
import SwiftData

enum WidgetEventType: String, Codable {
    case period
    case pill
    case love
}

@Model
final class WidgetUserEvent {
    var id: UUID
    var date: Date
    var typeRaw: String
    
    @Attribute(.unique)
    var uniqueKey: String
    
    init(id: UUID = .init(), date: Date, type: WidgetEventType, calendar: Calendar = .current) {
        self.id = id
        self.date = date
        self.typeRaw = type.rawValue
        self.uniqueKey = Self.makeUniqueKey(date: date, type: type, calendar: calendar)
    }
    
    static func makeUniqueKey(date: Date, type: WidgetEventType, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let dayKey = (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
        return "\(dayKey)|\(type.rawValue)"
    }
}

enum WidgetSharedEventStore {
    static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    private static let storeFileName = "BloodyDay.sqlite"
    
    static func toggle(_ type: WidgetEventType, on date: Date, calendar: Calendar = .current) -> Bool {
        let context = ModelContext(modelContainer())
        let target = calendar.startOfDay(for: date)
        let key = WidgetUserEvent.makeUniqueKey(date: target, type: type, calendar: calendar)
        let descriptor = FetchDescriptor<WidgetUserEvent>(
            predicate: #Predicate<WidgetUserEvent> { $0.uniqueKey == key }
        )
        
        do {
            let existing = try context.fetch(descriptor)
            if let event = existing.first {
                context.delete(event)
                try context.save()
                return false
            } else {
                context.insert(WidgetUserEvent(date: target, type: type, calendar: calendar))
                try context.save()
                return true
            }
        } catch {
            assertionFailure("Widget event toggle failed: \(error)")
            return false
        }
    }
    
    private static func modelContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: WidgetUserEvent.self,
                configurations: ModelConfiguration(url: storeURL())
            )
        } catch {
            fatalError("Failed to create widget shared model container: \(error)")
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
