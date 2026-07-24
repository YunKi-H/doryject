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
                PillCycle.self,
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
            let settings = loadSettings()
            PillCyclePersistence.migrateIfNeeded(
                in: context,
                settings: settings,
                calendar: calendar
            )
            let events = try fetchEvents(in: context, calendar: calendar)
            let existingDatesByType = Dictionary(
                grouping: events,
                by: \.type
            ).mapValues { Set($0.map(\.date)) }
            let toggledOn = !(existingDatesByType[type] ?? []).contains(target)
            let plan = CalendarEventTogglePolicyUseCase.mutationPlan(
                type: type,
                enabled: toggledOn,
                selectedDate: target,
                existingDatesByType: existingDatesByType,
                settings: settings,
                pillCycles: PillCyclePersistence.cycleInfos(
                    in: context,
                    calendar: calendar
                ),
                calendar: calendar
            )
            try apply(
                plan: plan,
                in: context,
                existingEvents: events,
                settings: settings,
                calendar: calendar
            )
            return toggledOn
        } catch {
            assertionFailure("Widget event toggle failed: \(error)")
            return false
        }
    }
    
    static func allEvents() -> [UserEvent] {
        let context = ModelContext(sharedContainer)
        let calendar = Calendar.current
        PillCyclePersistence.migrateIfNeeded(
            in: context,
            settings: loadSettings(),
            calendar: calendar
        )
        do {
            return try fetchEvents(in: context, calendar: calendar)
        } catch {
            assertionFailure("Widget event fetch failed: \(error)")
            return []
        }
    }

    static func pillCycles() -> [PillCycleInfo] {
        let context = ModelContext(sharedContainer)
        let calendar = Calendar.current
        PillCyclePersistence.migrateIfNeeded(
            in: context,
            settings: loadSettings(),
            calendar: calendar
        )
        return PillCyclePersistence.cycleInfos(in: context, calendar: calendar)
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

    private static func fetchEvents(
        in context: ModelContext,
        calendar: Calendar
    ) throws -> [UserEvent] {
        try context.fetch(FetchDescriptor<UserEvent>())
            .map { event in
                event.normalizeDate(calendar: calendar)
                return event
            }
            .sorted { $0.date < $1.date }
    }

    private static func apply(
        plan: CalendarEventMutationPlan,
        in context: ModelContext,
        existingEvents: [UserEvent],
        settings: UserSettings,
        calendar: Calendar
    ) throws {
        guard plan.isEmpty == false else { return }

        var eventsByKey = Dictionary(
            uniqueKeysWithValues: existingEvents.map { ($0.uniqueKey, $0) }
        )

        var deletedCycleIDs: Set<UUID> = []
        for mutation in plan.deletions {
            for date in mutation.dates {
                let key = UserEvent.makeUniqueKey(date: date, type: mutation.type, calendar: calendar)
                if let event = eventsByKey.removeValue(forKey: key) {
                    if let cycleID = event.pillCycleID {
                        deletedCycleIDs.insert(cycleID)
                    }
                    context.delete(event)
                }
            }
        }

        for mutation in plan.additions {
            for date in mutation.dates.sorted() {
                let key = UserEvent.makeUniqueKey(date: date, type: mutation.type, calendar: calendar)
                guard eventsByKey[key] == nil else { continue }
                let event = UserEvent(date: date, type: mutation.type, calendar: calendar)
                try PillCyclePersistence.assignCycle(
                    to: event,
                    in: context,
                    settings: settings,
                    calendar: calendar
                )
                context.insert(event)
                eventsByKey[key] = event
            }
        }

        try PillCyclePersistence.cleanupAfterDeletion(
            cycleIDs: deletedCycleIDs,
            in: context,
            calendar: calendar
        )
        try context.save()
    }
}
