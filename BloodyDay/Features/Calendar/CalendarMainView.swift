//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    @Bindable var viewModel: CalendarViewModel
    @Bindable var notificationViewModel: NotificationSettingsViewModel
    @Bindable var periodSettingViewModel: PeriodSettingViewModel
    @Bindable var pillViewModel: PillSettingsViewModel
    @Bindable var appleCalendarViewModel: AppleCalendarSettingViewModel
    @Bindable var appearanceViewModel: AppearanceSettingViewModel
    @Bindable var calendarSharingViewModel: CalendarSharingSettingViewModel
    @State private var selectionMonth: Date?
    
    @Binding var isPresentedEventSheet: Bool
    
    @State private var period: Bool = false
    @State private var pill: Bool = false
    @State private var love: Bool = false
    @State private var isPillDisableDialogPresented: Bool = false
    @State private var pillDisablePlan: PillDisableConfirmationPlan?
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                month: viewModel.months[viewModel.currentIndex].monthDate,
                onSelectDate: { date in
                    viewModel.selectDate(date)
                    withAnimation {
                        selectionMonth = date.startOfMonth
                    }
                },
                notificationViewModel: notificationViewModel,
                periodSettingViewModel: periodSettingViewModel,
                pillViewModel: pillViewModel,
                appleCalendarViewModel: appleCalendarViewModel,
                appearanceViewModel: appearanceViewModel,
                calendarSharingViewModel: calendarSharingViewModel
            )
            
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.months) { month in
                        CalendarView(
                            month: month,
                            selectedDate: viewModel.selectedDate,
                            onSelectDate: {
                                if viewModel.selectedDate.isSameDay(as: $0) {
                                    isPresentedEventSheet = true
                                }
                                viewModel.selectDate($0)
                            }
                        )
                        .containerRelativeFrame(.vertical)
                        .id(month.monthDate)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectionMonth, anchor: .top)
            .onAppear {
                viewModel.refresh()
                if viewModel.months.indices.contains(viewModel.currentIndex) {
                    selectionMonth = viewModel.months[viewModel.currentIndex].monthDate
                }
            }
            .onChange(of: viewModel.selectedDate, { oldValue, newValue in
                if !oldValue.isInSameMonth(as: newValue) {
                    DispatchQueue.main.async {
                        withAnimation {
                            selectionMonth = newValue.startOfMonth
                        }
                    }
                }
            })
            .onScrollPhaseChange { _, newPhase in
                switch newPhase {
                case .idle:
                    // 스크롤이 완전히 멈춘 시점에서만 동기화
                    guard let month = selectionMonth,
                          let index = viewModel.months.firstIndex(where: { $0.monthDate == month }) else { return }
                    
                    // 같은 페이지면 불필요한 업데이트 방지
                    guard index != viewModel.currentIndex ||
                            viewModel.months[index].monthDate.startOfMonth != viewModel.selectedDate.startOfMonth else { return }
                    
                    viewModel.setCurrentMonth(to: viewModel.months[index].monthDate)
                    
                case .animating, .decelerating, .interacting, .tracking:
                    break
                @unknown default:
                    break
                }
            }
            
            DayInfoCardView(
                date: viewModel.selectedDate,
                primaryStatus: viewModel.primaryStatus(for: viewModel.selectedDate),
                secondaryStatus: viewModel.secondaryStatus(for: viewModel.selectedDate),
                hasLoveEvent: viewModel.isEventOnSelectedDate(.love)
            )
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .appGradientOverlay()
        .sheet(isPresented: $isPresentedEventSheet) {
            let periodIconColor: Color = .mainRed
            let pillIconColor: Color = .subBlue
            let loveIconColor: Color = .subPink
            NavigationStack {
                Form {
                    Section(header: EmptyView()) {
                        Toggle(isOn: $period) {
                            Label {
                                Text("생리")
                            } icon: {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(periodIconColor)
                            }
                        }
                        .tint(.mainRed)
                        .onChange(of: period) { _, newValue in
                            viewModel.setEvent(.period, enabled: newValue)
                        }
                        
                        Toggle(isOn: $pill) {
                            Label {
                                Text("피임약 복용")
                            } icon: {
                                Image(.pillHalf)
                                    .foregroundStyle(pillIconColor)
                            }
                        }
                        .tint(.subBlue)
                        .onChange(of: pill) { oldValue, newValue in
                            guard oldValue != newValue else { return }
                            handlePillToggleChange(newValue: newValue)
                        }
                        
                        Toggle(isOn: $love) {
                            Label {
                                Text("사랑한 날")
                            } icon: {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(loveIconColor)
                            }
                        }
                        .tint(.subPink)
                        .onChange(of: love) { _, newValue in
                            viewModel.setEvent(.love, enabled: newValue)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                }
                .scrollDisabled(true)
                .padding(.top, 14)
                .contentMargins(.top, 0)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.moveSelectedDate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                    
                    ToolbarItem(placement: .title) {
                        let selectedDate = viewModel.selectedDate
                        let month = selectedDate.component(.month)
                        let day = selectedDate.component(.day)
                        let weekDay = Date.FormatStyle()
                            .weekday(.wide)
                            .format(selectedDate)
                        Text("\(month)월 \(day)일 \(weekDay)")
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.moveSelectedDate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .appGradientOverlay()
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.visible)
            .onAppear {
                syncToggleState()
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                syncToggleState()
            }
        }
        .confirmationDialog(
            "피임약 복용을 중단하시겠습니까?\n아직 예정된 복용이 \(pillDisablePlan?.remainingCount ?? 0)정 남았습니다.",
            isPresented: $isPillDisableDialogPresented,
            titleVisibility: .visible
        ) {
            Button("오늘만 미복용") {
                viewModel.deletePillEvents(on: pillDisablePlan?.todayOnlyDeleteDates ?? [])
                clearPillDisableDialogContext()
                syncToggleState()
            }
            Button("복용 중단", role: .destructive) {
                viewModel.deletePillEvents(on: pillDisablePlan?.stopCycleDeleteDates ?? [])
                clearPillDisableDialogContext()
                syncToggleState()
            }
        }
    }
    
    private func syncToggleState() {
        let states = viewModel.toggleStatesForSelectedDate()
        period = states.period
        pill = states.pill
        love = states.love
    }
    
    private func handlePillToggleChange(newValue: Bool) {
        if newValue {
            viewModel.setEvent(.pill, enabled: true)
            syncToggleState()
            return
        }
        
        if let plan = viewModel.pillDisableConfirmationPlanForSelectedDate() {
            pillDisablePlan = plan
            isPillDisableDialogPresented = true
            return
        }
        
        viewModel.setEvent(.pill, enabled: false)
        syncToggleState()
    }
    
    private func clearPillDisableDialogContext() {
        isPillDisableDialogPresented = false
        pillDisablePlan = nil
    }
}

#Preview {
    CalendarMainView(
        viewModel: .init(eventRepository: MockEventRepository()),
        notificationViewModel: .init(
            repo: UserDefaultsSettingsRepository(),
            scheduler: NoopNotificationScheduler(),
            eventRepository: MockEventRepository()
        ),
        periodSettingViewModel: .init(repo: UserDefaultsSettingsRepository()),
        pillViewModel: .init(repo: UserDefaultsSettingsRepository()),
        appleCalendarViewModel: .init(
            repo: UserDefaultsSettingsRepository(),
            calendarClient: NoopAppleCalendarClient(),
            syncService: AppleCalendarSyncService(
                settingsRepository: UserDefaultsSettingsRepository(),
                eventRepository: MockEventRepository(),
                calendarClient: NoopAppleCalendarClient(),
                syncStore: UserDefaultsAppleCalendarSyncStore()
            )
        ),
        appearanceViewModel: .init(repo: UserDefaultsSettingsRepository()),
        calendarSharingViewModel: .init(
            authenticationService: PreviewAuthenticationService(),
            connectionRepository: PreviewCalendarConnectionRepository()
        ),
        isPresentedEventSheet: .constant(false)
    )
}
