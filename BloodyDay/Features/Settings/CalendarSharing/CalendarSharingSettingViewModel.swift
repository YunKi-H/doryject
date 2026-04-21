//
//  CalendarSharingSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation
import Observation

@Observable
final class CalendarSharingSettingViewModel {
    private let repo: SettingsRepository
    private let sharedCalendarRepository: SharedCalendarRepository
    
    private(set) var selectedScope: CalendarScope
    private(set) var sharedCalendars: [SharedCalendar] = []
    var managingCalendar: SharedCalendar?
    var sharedEventTypeSelection: SharedEventTypeSelection = .none
    
    init(
        repo: SettingsRepository,
        sharedCalendarRepository: SharedCalendarRepository
    ) {
        self.repo = repo
        self.sharedCalendarRepository = sharedCalendarRepository
        self.selectedScope = repo.load().calendarScope.selectedScope
        reload()
    }
    
    func reload() {
        sharedCalendars = sharedCalendarRepository.calendars()
        
        let storedScope = repo.load().calendarScope.selectedScope
        switch storedScope {
        case .mine:
            selectedScope = .mine
        case .shared(let id):
            selectedScope = sharedCalendars.contains(where: { $0.id == id }) ? .shared(id: id) : .mine
            if selectedScope == .mine {
                repo.update { $0.calendarScope.selectedScope = .mine }
            }
        }
    }
    
    func selectMine() {
        updateScope(.mine)
    }
    
    func selectSharedCalendar(id: String) {
        updateScope(.shared(id: id))
    }
    
    func isSelected(_ scope: CalendarScope) -> Bool {
        selectedScope == scope
    }
    
    func selectedDisplayName(for calendar: SharedCalendar) -> String {
        calendar.displayName
    }
    
    func manage(calendarId: String) {
        managingCalendar = sharedCalendars.first(where: { $0.id == calendarId })
    }
    
    func dismissManagement() {
        managingCalendar = nil
    }
    
    var selectedScopeDisplayName: String {
        switch selectedScope {
        case .mine:
            return CalendarScope.mine.fallbackDisplayName
        case .shared(let id):
            return sharedCalendars.first(where: { $0.id == id })?.displayName ?? CalendarScope.shared(id: id).fallbackDisplayName
        }
    }
    
    var isICloudAvailable: Bool {
        false
    }

    func setSharedEventType(_ type: EventType, enabled: Bool) {
        sharedEventTypeSelection.set(type, enabled: enabled)
    }
    
    private func updateScope(_ scope: CalendarScope) {
        selectedScope = scope
        repo.update {
            $0.calendarScope.selectedScope = scope
        }
    }
}
