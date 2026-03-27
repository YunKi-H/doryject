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
    private static let settingsKey = "user.settings.v1"
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
        
        do {
            let events = try context.fetch(
                FetchDescriptor<UserEvent>(
                    sortBy: [SortDescriptor(\UserEvent.date, order: .forward)]
                )
            )
            let existingDatesByType = Dictionary(
                grouping: events,
                by: \.type
            ).mapValues { Set($0.map(\.date)) }
            let settings = loadSettings()
            let toggledOn = !(existingDatesByType[type] ?? []).contains(target)
            let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
                type: type,
                enabled: toggledOn,
                selectedDate: target,
                existingDatesByType: existingDatesByType,
                settings: settings,
                calendar: calendar
            )
            try apply(plan: plan, in: context, existingEvents: events, calendar: calendar)
            return toggledOn
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

    private static func loadSettings() -> UserSettings {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return .init()
        }
        return settings
    }

    private static func apply(
        plan: CalendarEventMutationPlan,
        in context: ModelContext,
        existingEvents: [UserEvent],
        calendar: Calendar
    ) throws {
        guard plan.isEmpty == false else { return }

        var eventsByKey = Dictionary(
            uniqueKeysWithValues: existingEvents.map { ($0.uniqueKey, $0) }
        )

        for mutation in plan.deletions {
            for date in mutation.dates {
                let key = UserEvent.makeUniqueKey(date: date, type: mutation.type, calendar: calendar)
                if let event = eventsByKey.removeValue(forKey: key) {
                    context.delete(event)
                }
            }
        }

        for mutation in plan.additions {
            for date in mutation.dates {
                let key = UserEvent.makeUniqueKey(date: date, type: mutation.type, calendar: calendar)
                guard eventsByKey[key] == nil else { continue }
                let event = UserEvent(date: date, type: mutation.type, calendar: calendar)
                context.insert(event)
                eventsByKey[key] = event
            }
        }

        try context.save()
    }
}
