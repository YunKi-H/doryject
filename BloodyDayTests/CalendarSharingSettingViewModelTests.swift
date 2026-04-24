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
    func setSharedEventTypePersistsDefaultSelectionAndSyncsOwnedEvents() async throws {
        let settingsRepository = InMemorySettingsRepository(settings: UserSettings())
        let event = makeUserEvent(type: .pill)
        let eventRepository = StaticEventRepository(events: [event])
        let cloudSharingService = TestCloudSharingService()
        let cloudSharingSyncScheduler = TestCloudSharingSyncScheduler()
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            eventRepository: eventRepository,
            cloudSharingService: cloudSharingService,
            cloudSharingSyncScheduler: cloudSharingSyncScheduler
        )

        viewModel.setSharedEventType(.pill, enabled: false)
        try await waitUntil { await cloudSharingSyncScheduler.scheduledRequestsCount() == 1 }

        let savedSelection = settingsRepository.load().calendarSharing.defaultSharedEventTypes
        #expect(viewModel.sharedEventTypeSelection == SharedEventTypeSelection(period: true, pill: false, love: true))
        #expect(savedSelection == SharedEventTypeSelection(period: true, pill: false, love: true))
        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.settings.calendarSharing.defaultSharedEventTypes == savedSelection)
        #expect(await cloudSharingSyncScheduler.lastScheduledRequest()?.eventIDs == [event.id])
    }

    @Test
    func selectSharedCalendarPersistsScope() {
        let sharedCalendar = makeSharedCalendar(id: "shared-calendar")
        let settingsRepository = InMemorySettingsRepository(settings: UserSettings())
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            sharedCalendarRepository: InMemorySharedCalendarRepository(calendars: [sharedCalendar])
        )

        viewModel.selectSharedCalendar(id: sharedCalendar.id)

        #expect(viewModel.selectedScope == .shared(id: sharedCalendar.id))
        #expect(settingsRepository.load().calendarScope.selectedScope == .shared(id: sharedCalendar.id))
        #expect(viewModel.selectedScopeDisplayName == "민지 캘린더")
    }

    @Test
    func selectMinePersistsScope() {
        let sharedCalendar = makeSharedCalendar(id: "shared-calendar")
        var settings = UserSettings()
        settings.calendarScope.selectedScope = .shared(id: sharedCalendar.id)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            sharedCalendarRepository: InMemorySharedCalendarRepository(calendars: [sharedCalendar])
        )

        viewModel.selectMine()

        #expect(viewModel.selectedScope == .mine)
        #expect(settingsRepository.load().calendarScope.selectedScope == .mine)
    }

    @Test
    func prepareOwnedSharePassesSelectedTypesSettingsAndEvents() async throws {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.calendarSharing.defaultSharedEventTypes = SharedEventTypeSelection(period: false, pill: true, love: true)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let events = [
            makeUserEvent(type: .pill),
            makeUserEvent(type: .love)
        ]
        let eventRepository = StaticEventRepository(events: events)
        let cloudSharingService = TestCloudSharingService()
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            eventRepository: eventRepository,
            cloudSharingService: cloudSharingService
        )

        _ = try await viewModel.prepareOwnedShare()

        #expect(await cloudSharingService.lastPreparedSharedEventTypesValue() == SharedEventTypeSelection(period: false, pill: true, love: true))
        #expect(await cloudSharingService.lastPreparedSettingsValue()?.pill.pillEnabled == true)
        #expect(await cloudSharingService.lastPreparedEventIDs() == events.map(\.id))
    }

    @Test
    func prepareOwnedShareShowsPartialEventSyncWarningWithReason() async throws {
        let cloudSharingService = TestCloudSharingService()
        await cloudSharingService.setPreparedShare(makePreparedShare(
            eventSyncResult: .partiallyFailed(failedCount: 2, reason: "Permission Failure")
        ))
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)

        _ = try await viewModel.prepareOwnedShare()

        #expect(viewModel.eventSyncWarningMessage?.contains("일부 이벤트 2개") == true)
        #expect(viewModel.eventSyncWarningMessage?.contains("Permission Failure") == true)
    }

    @Test
    func prepareOwnedShareClearsEventSyncWarningWhenSynced() async throws {
        let cloudSharingService = TestCloudSharingService()
        await cloudSharingService.setPreparedShare(makePreparedShare(
            eventSyncResult: .failed(reason: "network")
        ))
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)

        _ = try await viewModel.prepareOwnedShare()
        await cloudSharingService.setPreparedShare(makePreparedShare(eventSyncResult: .synced))
        _ = try await viewModel.prepareOwnedShare()

        #expect(viewModel.eventSyncWarningMessage == nil)
    }

    @Test
    func refreshOwnedShareStateReflectsFetchedShare() async {
        let cloudSharingService = TestCloudSharingService()
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)

        await viewModel.refreshOwnedShareState()
        #expect(viewModel.hasOwnedShare == false)

        await cloudSharingService.setOwnedShare(makeShare())
        await viewModel.refreshOwnedShareState()
        #expect(viewModel.hasOwnedShare == true)
    }

    @Test
    func refreshICloudAvailabilityReflectsServiceStatus() async {
        let cloudSharingService = TestCloudSharingService()
        await cloudSharingService.setAvailability(.noAccount)
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
        #expect(await cloudSharingService.leftCalendarIDsValue() == [sharedCalendar.id])
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
        await cloudSharingService.setLeaveSharedCalendarError(CloudSharingError.missingSharedCalendarReference)
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
    func reloadKeepsSelectedSharedCalendarWhenCalendarStillExists() async {
        let sharedCalendar = makeSharedCalendar(id: "shared-calendar")
        var settings = UserSettings()
        settings.calendarScope.selectedScope = .shared(id: sharedCalendar.id)
        let settingsRepository = InMemorySettingsRepository(settings: settings)
        let viewModel = makeViewModel(
            settingsRepository: settingsRepository,
            sharedCalendarRepository: InMemorySharedCalendarRepository(calendars: [sharedCalendar])
        )

        await viewModel.refreshSharedCalendars()

        #expect(viewModel.selectedScope == .shared(id: sharedCalendar.id))
        #expect(settingsRepository.load().calendarScope.selectedScope == .shared(id: sharedCalendar.id))
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

        #expect(await cloudSharingService.didStopOwnedSharingValue() == true)
        #expect(viewModel.hasOwnedShare == false)
        #expect(viewModel.preparedShare == nil)
        #expect(viewModel.sharePresentationID == nil)
        #expect(sharedCalendarRepository.refreshCallCount == 1)
    }

    @Test
    func stopOwnedSharingFailureKeepsPreparedShareAndShowsError() async {
        let cloudSharingService = TestCloudSharingService()
        await cloudSharingService.setStopOwnedSharingError(CloudSharingError.shareSaveFailed)
        let viewModel = makeViewModel(cloudSharingService: cloudSharingService)
        let share = makeShare()
        let presentationID = UUID()
        await cloudSharingService.setOwnedShare(share)
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
        cloudSharingService: TestCloudSharingService = .init(),
        cloudSharingSyncScheduler: CloudSharingSyncScheduling? = nil
    ) -> CalendarSharingSettingViewModel {
        CalendarSharingSettingViewModel(
            repo: settingsRepository,
            eventRepository: eventRepository,
            sharedCalendarRepository: sharedCalendarRepository,
            cloudSharingService: cloudSharingService,
            cloudSharingSyncScheduler: cloudSharingSyncScheduler
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

    private func makeUserEvent(type: EventType) -> UserEvent {
        UserEvent(date: Date().startOfDay, type: type)
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
