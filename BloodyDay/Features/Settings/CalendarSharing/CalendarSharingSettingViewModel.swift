//
//  CalendarSharingSettingViewModel.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class CalendarSharingSettingViewModel {
    private let repo: SettingsRepository
    private let sharedCalendarRepository: SharedCalendarRepository
    private let cloudSharingService: CloudSharingService
    
    private(set) var selectedScope: CalendarScope
    private(set) var sharedCalendars: [SharedCalendar] = []
    var managingCalendar: SharedCalendar?
    var sharedEventTypeSelection: SharedEventTypeSelection = .none
    private(set) var iCloudAvailability: CloudSharingAvailability = .couldNotDetermine
    
    init(
        repo: SettingsRepository,
        sharedCalendarRepository: SharedCalendarRepository,
        cloudSharingService: CloudSharingService
    ) {
        self.repo = repo
        self.sharedCalendarRepository = sharedCalendarRepository
        self.cloudSharingService = cloudSharingService
        self.selectedScope = repo.load().calendarScope.selectedScope
        reload()
    }
    
    func reload() {
        if let reloadingRepository = sharedCalendarRepository as? SharedCalendarReloading {
            Task {
                await reloadingRepository.refresh()
                reloadStoredState()
            }
        } else {
            reloadStoredState()
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
        iCloudAvailability == .available
    }
    
    var iCloudStatusText: String {
        switch iCloudAvailability {
        case .available:
            return "사용 가능"
        case .noAccount:
            return "로그인 필요"
        case .restricted:
            return "사용 제한"
        case .temporarilyUnavailable:
            return "일시적 오류"
        case .couldNotDetermine:
            return "확인 불가"
        }
    }

    func refreshICloudAvailability() {
        Task {
            iCloudAvailability = await cloudSharingService.fetchAvailability()
        }
    }

    func accept(_ metadata: CKShare.Metadata) {
        Task {
            do {
                try await cloudSharingService.accept(metadata)
                refreshICloudAvailability()
            } catch {
                iCloudAvailability = .couldNotDetermine
            }
        }
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
    
    private func reloadStoredState() {
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
}
