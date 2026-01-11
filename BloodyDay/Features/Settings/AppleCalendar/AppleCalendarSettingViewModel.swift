//
//  AppleCalendarSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation
import Observation

@Observable
final class AppleCalendarSettingViewModel {
    private let repo: SettingsRepository
    private let calendarClient: AppleCalendarClient
    private let syncService: AppleCalendarSyncService
    private(set) var settings: UserSettings
    private let supportedTypes: [EventType] = [.period, .pill, .love]

    init(
        repo: SettingsRepository,
        calendarClient: AppleCalendarClient,
        syncService: AppleCalendarSyncService
    ) {
        self.repo = repo
        self.calendarClient = calendarClient
        self.syncService = syncService
        self.settings = repo.load()
        ensureDefaults()
    }

    func setEnabled(_ enabled: Bool) async {
        settings.appleCalendar.isEnabled = enabled
        repo.save(settings)
        if enabled {
            await setupCalendarsIfNeeded()
            await syncService.syncAll()
        } else {
            let identifiers = ownedCalendarIdentifiers()
            await syncService.disableAll(calendarIdentifiers: identifiers)
            settings.appleCalendar.calendarIdentifiers = [:]
            settings.appleCalendar.calendarOwnership = [:]
            repo.save(settings)
        }
    }
    
    func setEventEnabled(_ type: EventType, _ enabled: Bool) async {
        guard supportedTypes.contains(type) else { return }
        settings.appleCalendar.eventSyncEnabled[type] = enabled
        repo.save(settings)
        if enabled && settings.appleCalendar.isEnabled {
            await ensureCalendar(for: type)
            await syncService.syncAll()
        } else if !enabled {
            if settings.appleCalendar.calendarOwnership[type] == true {
                await syncService.disable(type: type, calendarIdentifier: settings.appleCalendar.calendarIdentifiers[type])
            }
            settings.appleCalendar.calendarIdentifiers[type] = nil
            settings.appleCalendar.calendarOwnership[type] = nil
            repo.save(settings)
            await syncService.syncAll()
        }
    }
    
    func setCalendarName(_ type: EventType, _ name: String) async {
        guard supportedTypes.contains(type) else { return }
        settings.appleCalendar.calendarNames[type] = name
        repo.save(settings)
        if settings.appleCalendar.isEnabled && isEventEnabled(type) {
            await ensureCalendar(for: type)
            await syncService.syncAll()
        }
    }

    func isEventEnabled(_ type: EventType) -> Bool {
        settings.appleCalendar.eventSyncEnabled[type] ?? false
    }

    func calendarName(for type: EventType) -> String {
        settings.appleCalendar.calendarNames[type] ?? AppleCalendarSettings.defaultCalendarNames[type, default: "BloodyDay"]
    }

    func calendarIdentifier(for type: EventType) -> String? {
        settings.appleCalendar.calendarIdentifiers[type]
    }

    private func setupCalendarsIfNeeded() async {
        guard await calendarClient.requestAccess() else { return }
        for type in supportedTypes where isEventEnabled(type) {
            await ensureCalendar(for: type)
        }
    }

    private func ensureCalendar(for type: EventType) async {
        guard await calendarClient.requestAccess() else { return }
        let name = calendarName(for: type)
        let existing = settings.appleCalendar.calendarIdentifiers[type]
        let identifier = calendarClient.createOrFetchCalendar(name: name, existingIdentifier: existing)
        if let identifier {
            settings.appleCalendar.calendarIdentifiers[type] = identifier
            if existing == nil {
                settings.appleCalendar.calendarOwnership[type] = true
            }
            repo.save(settings)
        }
    }

    private func ensureDefaults() {
        if settings.appleCalendar.calendarNames.isEmpty {
            settings.appleCalendar.calendarNames = AppleCalendarSettings.defaultCalendarNames
        }
        if settings.appleCalendar.eventSyncEnabled.isEmpty {
            settings.appleCalendar.eventSyncEnabled = AppleCalendarSettings.defaultEventSyncEnabled
        }
        repo.save(settings)
    }

    private func ownedCalendarIdentifiers() -> [EventType: String] {
        settings.appleCalendar.calendarIdentifiers.filter { settings.appleCalendar.calendarOwnership[$0.key] == true }
    }
}
