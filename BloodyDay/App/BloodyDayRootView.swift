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
    @State private var appleCalendarClient: EventKitAppleCalendarClient?
    @State private var appleCalendarSyncService: AppleCalendarSyncService?
    @State private var notificationScheduler: UserNotificationScheduler?
    @State private var widgetReloadService: WidgetReloadService?
    
    @State private var activeTab: BloodyDayTab = .calendar
    @State private var isPresentedCalendarSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            TabView(selection: $activeTab) {
                Tab.init(value: .calendar) {
                    if let viewModel = calendarViewModel,
                       let notificationViewModel = notificationSettingsViewModel,
                       let periodSettingViewModel = periodSettingViewModel,
                       let pillViewModel = pillSettingsViewModel,
                       let appleCalendarViewModel = appleCalendarSettingsViewModel,
                       let appearanceViewModel = appearanceSettingViewModel {
                        CalendarMainView(
                            viewModel: viewModel,
                            notificationViewModel: notificationViewModel,
                            periodSettingViewModel: periodSettingViewModel,
                            pillViewModel: pillViewModel,
                            appleCalendarViewModel: appleCalendarViewModel,
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
                appleCalendarClient = calendarClient
                notificationScheduler = scheduler
                widgetReloadService = widgetReloader
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
                        settingsRepository: settingsRepository
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
                if appearanceSettingViewModel == nil {
                    appearanceSettingViewModel = AppearanceSettingViewModel(repo: settingsRepository)
                }
                refreshAppStateAfterExternalChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshAppStateAfterExternalChanges()
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
    
    private func refreshAppStateAfterExternalChanges() {
        calendarViewModel?.refresh()
        periodListViewModel?.refresh()
        pillSettingsViewModel?.reload()
        appearanceSettingViewModel?.reload()
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
                
                if activeTab == .calendar {
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
