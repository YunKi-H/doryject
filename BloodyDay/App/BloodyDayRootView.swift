//
//  BloodyDayRootView.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import SwiftUI
import UIKit
import SwiftData

struct BloodyDayRootView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var calendarViewModel: CalendarViewModel?
    @State private var periodListViewModel: PeriodListViewModel?
    @State private var periodSettingViewModel: PeriodSettingViewModel?
    @State private var notificationSettingsViewModel: NotificationSettingsViewModel?
    @State private var pillSettingsViewModel: PillSettingsViewModel?
    @State private var appleCalendarSettingsViewModel: AppleCalendarSettingViewModel?
    @State private var appearanceSettingViewModel: AppearanceSettingViewModel?
    @State private var calendarSharingSettingViewModel: CalendarSharingSettingViewModel?
    @State private var appleCalendarClient: EventKitAppleCalendarClient?
    @State private var appleCalendarSyncService: AppleCalendarSyncService?
    @State private var notificationScheduler: UserNotificationScheduler?
    @State private var widgetReloadService: WidgetReloadService?
    @State private var firebaseAuthenticationService: FirebaseAuthenticationService?
    @State private var calendarConnectionRepository: FirestoreCalendarConnectionRepository?
    @State private var sharedCalendarSyncScheduler: SharedCalendarSyncScheduler?
    @State private var calendarDisplayEventRepository: CalendarDisplayEventRepository?
    @State private var sharedCalendarEventRepository: FirestoreSharedCalendarEventRepository?
    
    @State private var activeTab: BloodyDayTab = .calendar
    @State private var isPresentedCalendarSheet: Bool = false
    @State private var pendingDeepLink: AppDeepLink?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $activeTab) {
                Tab.init(value: .calendar) {
                    if let viewModel = calendarViewModel,
                       let notificationViewModel = notificationSettingsViewModel,
                       let periodSettingViewModel = periodSettingViewModel,
                       let pillViewModel = pillSettingsViewModel,
                       let appleCalendarViewModel = appleCalendarSettingsViewModel,
                       let appearanceViewModel = appearanceSettingViewModel,
                       let calendarSharingViewModel = calendarSharingSettingViewModel {
                        CalendarMainView(
                            viewModel: viewModel,
                            notificationViewModel: notificationViewModel,
                            periodSettingViewModel: periodSettingViewModel,
                            pillViewModel: pillViewModel,
                            appleCalendarViewModel: appleCalendarViewModel,
                            appearanceViewModel: appearanceViewModel,
                            calendarSharingViewModel: calendarSharingViewModel,
                            isPresentedEventSheet: $isPresentedCalendarSheet
                        )
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .safeAreaBar(edge: .bottom, spacing: 0) {
                            Text(".")
                                .blendMode(.destinationOver)
                                .frame(height: 62)
                                .opacity(0)
                        }
                    }
                }
                
                Tab.init(value: .period) {
                    if let viewModel = periodListViewModel,
                       let settingViewModel = periodSettingViewModel {
                        PeriodListView(
                            viewModel: viewModel,
                            periodSettingViewModel: settingViewModel
                        )
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .safeAreaBar(edge: .bottom, spacing: 0) {
                            Text(".")
                                .blendMode(.destinationOver)
                                .frame(height: 62)
                                .opacity(0)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                BloodyDayTabBarView()
                    .padding(.horizontal, 20)
            }
            .onAppear {
                let baseEventRepository = SwiftDataEventRepository(context: modelContext)
                let settingsRepository = UserDefaultsSettingsRepository()
                let syncStore = UserDefaultsAppleCalendarSyncStore()
                let calendarClient = appleCalendarClient ?? EventKitAppleCalendarClient()
                let scheduler = notificationScheduler ?? UserNotificationScheduler()
                let widgetReloader = widgetReloadService ?? WidgetReloadService()
                let authenticationService = firebaseAuthenticationService
                    ?? FirebaseAuthenticationService()
                let connectionRepository = calendarConnectionRepository
                    ?? FirestoreCalendarConnectionRepository()
                appleCalendarClient = calendarClient
                notificationScheduler = scheduler
                widgetReloadService = widgetReloader
                firebaseAuthenticationService = authenticationService
                calendarConnectionRepository = connectionRepository
                if appleCalendarSyncService == nil {
                    appleCalendarSyncService = AppleCalendarSyncService(
                        settingsRepository: settingsRepository,
                        eventRepository: baseEventRepository,
                        calendarClient: calendarClient,
                        syncStore: syncStore
                    )
                }
                let sharingSyncScheduler: SharedCalendarSyncScheduler
                if let existingScheduler = sharedCalendarSyncScheduler {
                    sharingSyncScheduler = existingScheduler
                } else {
                    let createdScheduler = SharedCalendarSyncScheduler(
                        authenticationService: authenticationService,
                        connectionRepository: connectionRepository,
                        eventRepository: baseEventRepository,
                        eventSyncService: FirestoreSharedCalendarEventSyncService()
                    )
                    sharedCalendarSyncScheduler = createdScheduler
                    sharingSyncScheduler = createdScheduler
                }
                let syncingRepository = SyncingEventRepository(
                    base: baseEventRepository,
                    syncService: appleCalendarSyncService!,
                    settingsRepository: settingsRepository,
                    notificationScheduler: scheduler,
                    widgetReloader: widgetReloader,
                    sharedCalendarSyncScheduler: sharingSyncScheduler
                )
                let displayEventRepository = calendarDisplayEventRepository
                    ?? CalendarDisplayEventRepository(
                        localRepository: syncingRepository
                    )
                let remoteEventRepository = sharedCalendarEventRepository
                    ?? FirestoreSharedCalendarEventRepository()
                calendarDisplayEventRepository = displayEventRepository
                sharedCalendarEventRepository = remoteEventRepository
                let activeCalendarViewModel: CalendarViewModel
                if let existingCalendarViewModel = calendarViewModel {
                    activeCalendarViewModel = existingCalendarViewModel
                } else {
                    let createdViewModel = CalendarViewModel(
                        eventRepository: displayEventRepository,
                        settingsRepository: settingsRepository
                    )
                    self.calendarViewModel = createdViewModel
                    activeCalendarViewModel = createdViewModel
                }
                displayEventRepository.onDisplayEventsChanged = {
                    activeCalendarViewModel.refreshDisplayMode(
                        canEditEvents: displayEventRepository
                            .isDisplayingSharedCalendar == false
                    )
                }
                let settingsChangeRefresher = SettingsChangeRefreshService(
                    eventRepository: baseEventRepository,
                    notificationScheduler: scheduler,
                    appleCalendarSyncService: appleCalendarSyncService!,
                    widgetReloader: widgetReloader,
                    calendarStateRefresher: { [weak activeCalendarViewModel] in
                        activeCalendarViewModel?.refresh()
                    }
                )
                if periodListViewModel == nil {
                    periodListViewModel = PeriodListViewModel(eventRepository: syncingRepository)
                }
                if periodSettingViewModel == nil {
                    periodSettingViewModel = PeriodSettingViewModel(
                        repo: settingsRepository,
                        eventRepository: syncingRepository,
                        settingsChangeRefresher: settingsChangeRefresher
                    )
                }
                if notificationSettingsViewModel == nil {
                    notificationSettingsViewModel = NotificationSettingsViewModel(
                        repo: settingsRepository,
                        scheduler: scheduler,
                        eventRepository: syncingRepository
                    )
                }
                if pillSettingsViewModel == nil {
                    pillSettingsViewModel = PillSettingsViewModel(
                        repo: settingsRepository,
                        settingsChangeRefresher: settingsChangeRefresher
                    )
                }
                if appleCalendarSettingsViewModel == nil {
                    appleCalendarSettingsViewModel = AppleCalendarSettingViewModel(
                        repo: settingsRepository,
                        calendarClient: calendarClient,
                        syncService: appleCalendarSyncService!
                    )
                }
                if appearanceSettingViewModel == nil {
                    appearanceSettingViewModel = AppearanceSettingViewModel(repo: settingsRepository)
                }
                if calendarSharingSettingViewModel == nil {
                    let sharingViewModel = CalendarSharingSettingViewModel(
                        authenticationService: authenticationService,
                        connectionRepository: connectionRepository,
                        sharedCalendarSyncScheduler: sharingSyncScheduler,
                        sharedEventRepository: remoteEventRepository,
                        calendarDisplayUpdater: displayEventRepository
                    )
                    calendarSharingSettingViewModel = sharingViewModel
                    Task {
                        await sharingViewModel.refreshSharingState()
                    }
                }
                refreshAppStateForSystemCalendarChange()
                consumePendingDeepLinkIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshAppStateForSystemCalendarChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshAppStateForSystemCalendarChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                refreshAppStateForSystemCalendarChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                refreshAppStateForSystemCalendarChange()
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func refreshAppStateForSystemCalendarChange(
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        calendarViewModel?.refreshForSystemCalendarChange(
            now: now,
            calendar: calendar
        )
        periodListViewModel?.refresh()
        pillSettingsViewModel?.reload()
        appearanceSettingViewModel?.reload()
        notificationSettingsViewModel?.refreshSchedules()
        Task {
            await appleCalendarSyncService?.syncAll()
        }
        widgetReloadService?.reloadAll()
        sharedCalendarSyncScheduler?.schedule()
    }
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceSettingViewModel?.selectedAppearance {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system, .none:
            return nil
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard let deepLink = AppDeepLink(url: url) else { return }
        
        if calendarViewModel == nil {
            pendingDeepLink = deepLink
            return
        }
        
        open(deepLink)
    }
    
    private func consumePendingDeepLinkIfNeeded() {
        guard let deepLink = pendingDeepLink else { return }
        pendingDeepLink = nil
        open(deepLink)
    }
    
    private func open(_ deepLink: AppDeepLink) {
        switch deepLink {
        case .calendar(let date):
            openCalendarTab(on: date)
        }
    }
    
    private func openCalendarTab(on date: Date) {
        activeTab = .calendar
        isPresentedCalendarSheet = false
        calendarViewModel?.selectDate(
            date.startOfDay(in: .autoupdatingCurrent)
        )
    }
    
    @ViewBuilder
    func BloodyDayTabBarView() -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 100) {
                GeometryReader {
                    BloodyDayTabBar(size: $0.size, activeTab: $activeTab) { tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .foregroundStyle(.icon)
                                .font(.title3)
                            
                            Text(tab.rawValue)
                                .font(.medium_11)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                
                if activeTab == .calendar,
                   calendarViewModel?.canEditEvents != false {
                    Circle()
                        .fill(.mainRed)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.textPoint)
                        }
                        .frame(width: 62, height: 62)
                        .glassEffect(.clear.interactive())
                        .onTapGesture {
                            isPresentedCalendarSheet = true
                        }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 62, height: 62)
                }
            }
            .frame(height: 62)
        }
    }
}

#Preview {
    BloodyDayRootView()
}
