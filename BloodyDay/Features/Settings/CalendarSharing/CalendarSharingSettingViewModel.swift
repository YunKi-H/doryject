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
    private let eventRepository: EventRepository
    private let sharedCalendarRepository: SharedCalendarRepository
    private let cloudSharingService: CloudSharingService
    
    private(set) var selectedScope: CalendarScope
    private(set) var sharedCalendars: [SharedCalendar] = []
    var managingCalendar: SharedCalendar?
    var sharedEventTypeSelection: SharedEventTypeSelection = .init(period: true, pill: true, love: true)
    private(set) var iCloudAvailability: CloudSharingAvailability = .couldNotDetermine
    private(set) var hasOwnedShare: Bool = false
    var sharePresentationID: UUID?
    private var presentedSharePresentationID: UUID?
    var preparedShare: CKShare?
    var isPreparingShare: Bool = false
    var isChangingShareState: Bool = false
    var sharePresentationErrorMessage: String?
    private(set) var eventSyncWarningMessage: String?
    
    init(
        repo: SettingsRepository,
        eventRepository: EventRepository,
        sharedCalendarRepository: SharedCalendarRepository,
        cloudSharingService: CloudSharingService
    ) {
        self.repo = repo
        self.eventRepository = eventRepository
        self.sharedCalendarRepository = sharedCalendarRepository
        self.cloudSharingService = cloudSharingService
        let settings = repo.load()
        self.selectedScope = settings.calendarScope.selectedScope
        self.sharedEventTypeSelection = settings.calendarSharing.defaultSharedEventTypes
        reload()
    }
    
    func reload() {
        reloadStoredState()
    }
    
    func refreshSharedCalendars() async {
        if let reloadingRepository = sharedCalendarRepository as? SharedCalendarReloading {
            await reloadingRepository.refresh()
        }
        reloadStoredState()
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
    
    var cloudContainerIdentifier: String {
        cloudSharingService.containerIdentifier
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
    
    func refreshOwnedShareState() {
        Task {
            do {
                hasOwnedShare = try await cloudSharingService.fetchOwnedShare() != nil
            } catch {
                hasOwnedShare = false
            }
        }
    }

    func setSharedEventType(_ type: EventType, enabled: Bool) {
        sharedEventTypeSelection.set(type, enabled: enabled)
        let selection = sharedEventTypeSelection
        repo.update {
            $0.calendarSharing.defaultSharedEventTypes = selection
        }
    }
    
    func presentShareSheet() {
        guard isPreparingShare == false else { return }
        
        isPreparingShare = true
        sharePresentationErrorMessage = nil
        eventSyncWarningMessage = nil
        presentedSharePresentationID = nil
        Task {
            do {
                let preparedShare = try await prepareOwnedShare()
                self.preparedShare = preparedShare
                hasOwnedShare = true
                sharePresentationID = UUID()
            } catch {
                preparedShare = nil
                sharePresentationID = nil
                presentedSharePresentationID = nil
                sharePresentationErrorMessage = error.localizedDescription
            }
            isPreparingShare = false
        }
    }
    
    func dismissShareSheet() {
        sharePresentationID = nil
        presentedSharePresentationID = nil
        preparedShare = nil
    }
    
    func handleSharePreparationFailure(_ error: Error) {
        sharePresentationID = nil
        presentedSharePresentationID = nil
        preparedShare = nil
        sharePresentationErrorMessage = error.localizedDescription
    }
    
    func dismissSharePresentationError() {
        sharePresentationErrorMessage = nil
    }
    
    func stopOwnedSharing() async {
        guard isChangingShareState == false else { return }
        isChangingShareState = true
        sharePresentationErrorMessage = nil
        do {
            try await cloudSharingService.stopOwnedSharing()
            dismissShareSheet()
            hasOwnedShare = false
            await refreshSharedCalendars()
        } catch {
            sharePresentationErrorMessage = error.localizedDescription
        }
        isChangingShareState = false
    }
    
    func leaveSharedCalendar(_ calendar: SharedCalendar) async {
        guard isChangingShareState == false else { return }
        isChangingShareState = true
        sharePresentationErrorMessage = nil
        do {
            try await cloudSharingService.leaveSharedCalendar(calendar)
            if isSelected(.shared(id: calendar.id)) {
                selectMine()
            }
            if let managingCalendar, managingCalendar.id == calendar.id {
                dismissManagement()
            }
            if let managingRepository = sharedCalendarRepository as? SharedCalendarManaging {
                managingRepository.removeLocalCalendar(calendarId: calendar.id)
            }
            await refreshSharedCalendars()
        } catch {
            sharePresentationErrorMessage = error.localizedDescription
        }
        isChangingShareState = false
    }
    
    func prepareOwnedShare() async throws -> CKShare {
        let preparedShare = try await cloudSharingService.prepareOwnedShare(
            sharedEventTypes: sharedEventTypeSelection,
            settings: repo.load(),
            events: eventRepository.allEvents()
        )
        eventSyncWarningMessage = warningMessage(for: preparedShare.eventSyncResult)
        return preparedShare.share
    }
    
    func shouldPresentShareController(for id: UUID) -> Bool {
        presentedSharePresentationID != id
    }
    
    func markShareControllerPresented(id: UUID) {
        guard sharePresentationID == id else { return }
        
        presentedSharePresentationID = id
    }
    
    private func updateScope(_ scope: CalendarScope) {
        selectedScope = scope
        repo.update {
            $0.calendarScope.selectedScope = scope
        }
    }
    
    private func warningMessage(for result: CloudSharingEventSyncResult) -> String? {
        switch result {
        case .synced:
            return nil
        case .partiallyFailed:
            return "공유는 준비됐지만 일부 이벤트가 아직 iCloud에 동기화되지 않았어요. 잠시 후 다시 공유 관리를 열어 동기화할 수 있습니다."
        case .failed:
            return "공유는 준비됐지만 이벤트가 아직 iCloud에 동기화되지 않았어요. 네트워크 상태를 확인한 뒤 다시 공유 관리를 열어주세요."
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
