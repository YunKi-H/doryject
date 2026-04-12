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
        let updated = repo.update {
            $0.appleCalendar.isEnabled = enabled
        }
        settings = updated
        if enabled {
            await setupCalendarsIfNeeded()
            await syncService.syncAll()
        } else {
            let identifiers = ownedCalendarIdentifiers(from: updated.appleCalendar)
            await syncService.disableAll(calendarIdentifiers: identifiers)
            settings = repo.update {
                $0.appleCalendar.calendarIdentifiers = [:]
                $0.appleCalendar.calendarOwnership = [:]
            }
        }
    }
    
    func setEventEnabled(_ type: EventType, _ enabled: Bool) async {
        guard supportedTypes.contains(type) else { return }
        let updated = repo.update {
            $0.appleCalendar.eventSyncEnabled[type] = enabled
        }
        settings = updated
        if enabled && updated.appleCalendar.isEnabled {
            await ensureCalendar(for: type)
            await syncService.syncAll()
        } else if !enabled {
            if updated.appleCalendar.calendarOwnership[type] == true {
                await syncService.disable(type: type, calendarIdentifier: updated.appleCalendar.calendarIdentifiers[type])
            }
            settings = repo.update {
                $0.appleCalendar.calendarIdentifiers[type] = nil
                $0.appleCalendar.calendarOwnership[type] = nil
            }
            await syncService.syncAll()
        }
    }
    
    func setCalendarName(_ type: EventType, _ name: String) async {
        guard supportedTypes.contains(type) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = repo.update {
            if trimmed.isEmpty {
                $0.appleCalendar.calendarNames[type] = nil
            } else {
                $0.appleCalendar.calendarNames[type] = trimmed
            }
        }
        settings = updated
        if updated.appleCalendar.isEnabled && isEventEnabled(type) {
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
    
    func calendarNameInput(for type: EventType) -> String {
        let stored = settings.appleCalendar.calendarNames[type]
        let fallback = AppleCalendarSettings.defaultCalendarNames[type, default: "BloodyDay"]
        if let stored, stored != fallback {
            return stored
        }
        return ""
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
            settings = repo.update {
                $0.appleCalendar.calendarIdentifiers[type] = identifier
                if existing == nil {
                    $0.appleCalendar.calendarOwnership[type] = true
                }
            }
        }
    }
    
    private func ensureDefaults() {
        settings = repo.update {
            if $0.appleCalendar.calendarNames.isEmpty {
                $0.appleCalendar.calendarNames = AppleCalendarSettings.defaultCalendarNames
            }
            if $0.appleCalendar.eventSyncEnabled.isEmpty {
                $0.appleCalendar.eventSyncEnabled = AppleCalendarSettings.defaultEventSyncEnabled
            }
        }
    }
    
    private func ownedCalendarIdentifiers(from appleCalendar: AppleCalendarSettings) -> [EventType: String] {
        appleCalendar.calendarIdentifiers.filter { appleCalendar.calendarOwnership[$0.key] == true }
    }
}
