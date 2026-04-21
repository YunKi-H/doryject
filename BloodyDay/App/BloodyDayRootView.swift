//
//  BloodyDayRootView.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import CloudKit
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
    @State private var calendarSharingSettingViewModel: CalendarSharingSettingViewModel?
    @State private var appearanceSettingViewModel: AppearanceSettingViewModel?
    @State private var appleCalendarClient: EventKitAppleCalendarClient?
    @State private var appleCalendarSyncService: AppleCalendarSyncService?
    @State private var notificationScheduler: UserNotificationScheduler?
    @State private var widgetReloadService: WidgetReloadService?
    @State private var cloudSharingService: CloudSharingService?
    @State private var cloudSharedCalendarRepository: CloudKitSharedCalendarRepository?
    
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
                       let calendarSharingViewModel = calendarSharingSettingViewModel,
                       let appearanceViewModel = appearanceSettingViewModel {
                        CalendarMainView(
                            viewModel: viewModel,
                            notificationViewModel: notificationViewModel,
                            periodSettingViewModel: periodSettingViewModel,
                            pillViewModel: pillViewModel,
                            appleCalendarViewModel: appleCalendarViewModel,
                            calendarSharingViewModel: calendarSharingViewModel,
                            appearanceViewModel: appearanceViewModel,
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
                let sharingService = cloudSharingService ?? CloudKitSharingService()
                let sharedCalendarRepository = cloudSharedCalendarRepository ?? CloudKitSharedCalendarRepository(
                    cloudSharingService: sharingService
                )
                appleCalendarClient = calendarClient
                notificationScheduler = scheduler
                widgetReloadService = widgetReloader
                cloudSharingService = sharingService
                cloudSharedCalendarRepository = sharedCalendarRepository
                if appleCalendarSyncService == nil {
                    appleCalendarSyncService = AppleCalendarSyncService(
                        settingsRepository: settingsRepository,
                        eventRepository: baseEventRepository,
                        calendarClient: calendarClient,
                        syncStore: syncStore
                    )
                }
                let syncingRepository = SyncingEventRepository(
                    base: baseEventRepository,
                    syncService: appleCalendarSyncService!,
                    settingsRepository: settingsRepository,
                    notificationScheduler: scheduler,
                    widgetReloader: widgetReloader
                )
                if calendarViewModel == nil {
                    calendarViewModel = CalendarViewModel(
                        eventRepository: syncingRepository,
                        settingsRepository: settingsRepository,
                        sharedCalendarRepository: sharedCalendarRepository
                    )
                }
                if periodListViewModel == nil {
                    periodListViewModel = PeriodListViewModel(eventRepository: syncingRepository)
                }
                if periodSettingViewModel == nil {
                    periodSettingViewModel = PeriodSettingViewModel(
                        repo: settingsRepository,
                        eventRepository: syncingRepository
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
                    pillSettingsViewModel = PillSettingsViewModel(repo: settingsRepository)
                }
                if appleCalendarSettingsViewModel == nil {
                    appleCalendarSettingsViewModel = AppleCalendarSettingViewModel(
                        repo: settingsRepository,
                        calendarClient: calendarClient,
                        syncService: appleCalendarSyncService!
                    )
                }
                if calendarSharingSettingViewModel == nil {
                    calendarSharingSettingViewModel = CalendarSharingSettingViewModel(
                        repo: settingsRepository,
                        sharedCalendarRepository: sharedCalendarRepository,
                        cloudSharingService: sharingService
                    )
                }
                if appearanceSettingViewModel == nil {
                    appearanceSettingViewModel = AppearanceSettingViewModel(repo: settingsRepository)
                }
                refreshAppStateAfterExternalChanges()
                consumePendingDeepLinkIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshAppStateAfterExternalChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: BloodyDayAppDelegate.didAcceptShareNotification)) { notification in
                guard let metadata = notification.userInfo?["metadata"] as? CKShare.Metadata else { return }
                Task {
                    do {
                        try await cloudSharingService?.accept(metadata)
                        await cloudSharedCalendarRepository?.refresh()
                        await MainActor.run {
                            calendarSharingSettingViewModel?.reload()
                            calendarViewModel?.refresh()
                            calendarSharingSettingViewModel?.refreshICloudAvailability()
                        }
                    } catch {
                    }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func refreshAppStateAfterExternalChanges() {
        calendarViewModel?.refresh()
        periodListViewModel?.refresh()
        pillSettingsViewModel?.reload()
        appearanceSettingViewModel?.reload()
        Task {
            await cloudSharedCalendarRepository?.refresh()
            await MainActor.run {
                calendarSharingSettingViewModel?.reload()
                calendarViewModel?.refresh()
            }
        }
        notificationSettingsViewModel?.refreshSchedules()
        Task {
            await appleCalendarSyncService?.syncAll()
        }
        widgetReloadService?.reloadAll()
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
        calendarViewModel?.selectDate(date.startOfDay)
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
                
                if activeTab == .calendar, calendarViewModel?.canEditEvents == true {
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
