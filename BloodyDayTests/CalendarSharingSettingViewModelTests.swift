//
//  CalendarSharingSettingViewModelTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/22/26.
//

import CloudKit
import Foundation
import Testing
@testable import BloodyDay

@MainActor
struct CalendarSharingSettingViewModelTests {
    @Test
    func setSharedEventTypePersistsDefaultSelection() {
        let settingsRepository = InMemorySettingsRepository(settings: UserSettings())
        let viewModel = makeViewModel(settingsRepository: settingsRepository)
        
        viewModel.setSharedEventType(.pill, enabled: false)
        
        let savedSelection = settingsRepository.load().calendarSharing.defaultSharedEventTypes
        #expect(viewModel.sharedEventTypeSelection == SharedEventTypeSelection(period: true, pill: false, love: true))
        #expect(savedSelection == SharedEventTypeSelection(period: true, pill: false, love: true))
    }
    
    @Test
    func prepareOwnedShareShowsPartialEventSyncWarningWithReason() async throws {
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.preparedShare = makePreparedShare(
            eventSyncResult: .partiallyFailed(failedCount: 2, reason: "Permission Failure")
        )
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)
        
        _ = try await viewModel.prepareOwnedShare()
        
        #expect(viewModel.eventSyncWarningMessage?.contains("일부 이벤트 2개") == true)
        #expect(viewModel.eventSyncWarningMessage?.contains("Permission Failure") == true)
    }
    
    @Test
    func prepareOwnedShareClearsEventSyncWarningWhenSynced() async throws {
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.preparedShare = makePreparedShare(
            eventSyncResult: .failed(reason: "network")
        )
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)
        
        _ = try await viewModel.prepareOwnedShare()
        cloudSharingService.preparedShare = makePreparedShare(eventSyncResult: .synced)
        _ = try await viewModel.prepareOwnedShare()
        
        #expect(viewModel.eventSyncWarningMessage == nil)
    }
    
    @Test
    func refreshOwnedShareStateReflectsFetchedShare() async {
        let cloudSharingService = TestCloudSharingService()
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)
        
        await viewModel.refreshOwnedShareState()
        #expect(viewModel.hasOwnedShare == false)
        
        cloudSharingService.ownedShare = makeShare()
        await viewModel.refreshOwnedShareState()
        #expect(viewModel.hasOwnedShare == true)
    }
    
    @Test
    func refreshICloudAvailabilityReflectsServiceStatus() async {
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.availability = .noAccount
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)
        
        await viewModel.refreshICloudAvailability()
        
        #expect(viewModel.iCloudAvailability == .noAccount)
        #expect(viewModel.iCloudStatusText == "로그인 필요")
    }
    
    @Test
    func leaveSelectedSharedCalendarReturnsToMineAndRemovesLocalCalendar() async {
        let sharedCalendar = makeSharedCalendar(id: "shared-calendar")
        var settings = UserSettings()
        settings.calendarScope.selectedScope = .shared(id: sharedCalendar.id)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let sharedCalendarRepository = InMemorySharedCalendarRepository(calendars: [sharedCalendar])
        let cloudSharingService = TestCloudSharingService()
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            sharedCalendarRepository: sharedCalendarRepository,
            cloudSharingService: cloudSharingService
        )
        viewModel.manage(calendarId: sharedCalendar.id)
        
        await viewModel.leaveSharedCalendar(sharedCalendar)
        
        #expect(viewModel.selectedScope == .mine)
        #expect(settingsRepository.load().calendarScope.selectedScope == .mine)
        #expect(viewModel.managingCalendar == nil)
        #expect(sharedCalendarRepository.removedCalendarIDs == [sharedCalendar.id])
        #expect(cloudSharingService.leftCalendarIDs == [sharedCalendar.id])
        #expect(sharedCalendarRepository.refreshCallCount == 1)
    }
    
    @Test
    func leaveSharedCalendarFailureKeepsLocalStateAndShowsError() async {
        let sharedCalendar = makeSharedCalendar(id: "shared-calendar")
        var settings = UserSettings()
        settings.calendarScope.selectedScope = .shared(id: sharedCalendar.id)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let sharedCalendarRepository = InMemorySharedCalendarRepository(calendars: [sharedCalendar])
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.leaveSharedCalendarError = CloudSharingError.missingSharedCalendarReference
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            sharedCalendarRepository: sharedCalendarRepository,
            cloudSharingService: cloudSharingService
        )
        
        await viewModel.leaveSharedCalendar(sharedCalendar)
        
        #expect(viewModel.selectedScope == .shared(id: sharedCalendar.id))
        #expect(sharedCalendarRepository.removedCalendarIDs.isEmpty)
        #expect(sharedCalendarRepository.refreshCallCount == 0)
        #expect(viewModel.sharePresentationErrorMessage == CloudSharingError.missingSharedCalendarReference.localizedDescription)
    }
    
    @Test
    func reloadReturnsToMineWhenSelectedSharedCalendarIsMissing() async {
        var settings = UserSettings()
        settings.calendarScope.selectedScope = .shared(id: "missing-calendar")
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let viewModel = makeViewModel(settingsRepository: settingsRepository)
        
        await viewModel.refreshSharedCalendars()
        
        #expect(viewModel.selectedScope == .mine)
        #expect(settingsRepository.load().calendarScope.selectedScope == .mine)
    }
    
    @Test
    func stopOwnedSharingClearsShareStateAndRefreshesCalendars() async {
        let sharedCalendarRepository = InMemorySharedCalendarRepository()
        let cloudSharingService = TestCloudSharingService()
        let viewModel = makeViewModel(
            sharedCalendarRepository: sharedCalendarRepository,
            cloudSharingService: cloudSharingService
        )
        viewModel.preparedShare = makeShare()
        viewModel.sharePresentationID = UUID()
        
        await viewModel.stopOwnedSharing()
        
        #expect(cloudSharingService.didStopOwnedSharing == true)
        #expect(viewModel.hasOwnedShare == false)
        #expect(viewModel.preparedShare == nil)
        #expect(viewModel.sharePresentationID == nil)
        #expect(sharedCalendarRepository.refreshCallCount == 1)
    }
    
    @Test
    func stopOwnedSharingFailureKeepsPreparedShareAndShowsError() async {
        let cloudSharingService = TestCloudSharingService()
        cloudSharingService.stopOwnedSharingError = CloudSharingError.shareSaveFailed
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)
        let share = makeShare()
        let presentationID = UUID()
        cloudSharingService.ownedShare = share
        viewModel.preparedShare = share
        viewModel.sharePresentationID = presentationID
        await viewModel.refreshOwnedShareState()
        
        await viewModel.stopOwnedSharing()
        
        #expect(viewModel.hasOwnedShare == true)
        #expect(viewModel.preparedShare === share)
        #expect(viewModel.sharePresentationID == presentationID)
        #expect(viewModel.sharePresentationErrorMessage == CloudSharingError.shareSaveFailed.localizedDescription)
    }
    
    private func makeViewModel(
        settingsRepository: InMemorySettingsRepository = .init(settings: UserSettings()),
        eventRepository: StaticEventRepository = .init(events: []),
        sharedCalendarRepository: InMemorySharedCalendarRepository = .init(),
        cloudSharingService: TestCloudSharingService = .init()
    ) -> CalendarSharingSettingViewModel {
        CalendarSharingSettingViewModel(
            repo: settingsRepository,
            eventRepository: eventRepository,
            sharedCalendarRepository: sharedCalendarRepository,
            cloudSharingService: cloudSharingService
        )
    }
    
    private func makePreparedShare(eventSyncResult: CloudSharingEventSyncResult) -> PreparedCloudShare {
        PreparedCloudShare(
            share: makeShare(),
            eventSyncResult: eventSyncResult
        )
    }
    
    private func makeShare() -> CKShare {
        let rootRecord = CKRecord(
            recordType: SharedCloudKitSchema.calendarRecordType,
            recordID: CKRecord.ID(recordName: "calendar")
        )
        return CKShare(rootRecord: rootRecord)
    }
    
    private func makeSharedCalendar(id: String) -> SharedCalendar {
        SharedCalendar(
            id: id,
            remoteTitle: "민지 캘린더",
            sharedEventTypes: .all,
            cloudZoneName: "shared-zone",
            cloudOwnerName: "owner",
            cloudShareRecordName: "share"
        )
    }
}

private final class InMemorySettingsRepository: SettingsRepository {
    private var current: UserSettings
    
    init(settings: UserSettings) {
        self.current = settings
    }
    
    func load() -> UserSettings {
        current
    }
    
    func save(_ settings: UserSettings) {
        current = settings
    }
}

private struct StaticEventRepository: EventRepository {
    let events: [UserEvent]
    
    func save(_ event: UserEvent) {}
    func delete(id: UUID) {}
    func delete(type: EventType, on: Date) {}
    func replace(type: EventType, on dates: Set<Date>) {}
    func allEvents() -> [UserEvent] { events }
    func events(forMonth month: Date) -> [UserEvent] { events }
    func events(of type: EventType) -> [UserEvent] { events.filter { $0.type == type } }
}

private final class InMemorySharedCalendarRepository: SharedCalendarRepository, SharedCalendarManaging, SharedCalendarReloading {
    private var storedCalendars: [SharedCalendar]
    private var storedEventsByCalendarID: [String: [SharedCalendarEvent]]
    private(set) var removedCalendarIDs: [String] = []
    private(set) var refreshCallCount = 0
    
    init(
        calendars: [SharedCalendar] = [],
        eventsByCalendarID: [String: [SharedCalendarEvent]] = [:]
    ) {
        self.storedCalendars = calendars
        self.storedEventsByCalendarID = eventsByCalendarID
    }
    
    func calendars() -> [SharedCalendar] {
        storedCalendars
    }
    
    func calendar(id: String) -> SharedCalendar? {
        storedCalendars.first { $0.id == id }
    }
    
    func events(calendarId: String) -> [SharedCalendarEvent] {
        storedEventsByCalendarID[calendarId] ?? []
    }
    
    func updateLocalDisplayName(calendarId: String, name: String?) {
        guard let index = storedCalendars.firstIndex(where: { $0.id == calendarId }) else { return }
        storedCalendars[index].localDisplayName = name
    }
    
    func removeLocalCalendar(calendarId: String) {
        removedCalendarIDs.append(calendarId)
        storedCalendars.removeAll { $0.id == calendarId }
        storedEventsByCalendarID.removeValue(forKey: calendarId)
    }
    
    @MainActor
    func refresh() async {
        refreshCallCount += 1
    }
}

private final class TestCloudSharingService: CloudSharingService {
    let containerIdentifier = "iCloud.test.BDay"
    var availability: CloudSharingAvailability = .available
    var ownedShare: CKShare?
    var preparedShare: PreparedCloudShare?
    var stopOwnedSharingError: Error?
    var leaveSharedCalendarError: Error?
    private(set) var didStopOwnedSharing = false
    private(set) var leftCalendarIDs: [String] = []
    
    func fetchAvailability() async -> CloudSharingAvailability {
        availability
    }
    
    func accept(_ metadata: CKShare.Metadata) async throws {}
    
    func fetchSharedSnapshot() async throws -> SharedCalendarSnapshot {
        SharedCalendarSnapshot(calendars: [], eventsByCalendarId: [:])
    }
    
    func fetchOwnedShare() async throws -> CKShare? {
        ownedShare
    }
    
    func stopOwnedSharing() async throws {
        if let stopOwnedSharingError {
            throw stopOwnedSharingError
        }
        didStopOwnedSharing = true
    }
    
    func leaveSharedCalendar(_ calendar: SharedCalendar) async throws {
        if let leaveSharedCalendarError {
            throw leaveSharedCalendarError
        }
        leftCalendarIDs.append(calendar.id)
    }
    
    func prepareOwnedShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> PreparedCloudShare {
        preparedShare ?? PreparedCloudShare(
            share: CKShare(rootRecord: CKRecord(recordType: SharedCloudKitSchema.calendarRecordType)),
            eventSyncResult: .synced
        )
    }
}
