//
//  CalendarHeaderView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarHeaderView: View {
    let month: Date
    let onSelectDate: (Date) -> Void
    let notificationViewModel: NotificationSettingsViewModel
    let periodSettingViewModel: PeriodSettingViewModel
    let pillViewModel: PillSettingsViewModel
    let appleCalendarViewModel: AppleCalendarSettingViewModel
    let appearanceViewModel: AppearanceSettingViewModel
    let calendarSharingViewModel: CalendarSharingSettingViewModel
    
    @State private var datePickerPresented: Bool = false
    @State private var newDate: Date = .now
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(month.component(.year).formatted(.number.grouping(.never)))년")
                        .font(.medium_16)
                        .padding(.leading, 1)
                    
                    HStack(spacing: 9) {
                        Text("\(month.component(.month))월")
                            .font(.semibold_32)
                        
                        Image(systemName: "chevron.right")
                            .bold()
                            .foregroundStyle(.icon)
                            .frame(width: 13, height: 16)
                            .rotationEffect(datePickerPresented ? .degrees(90) : .degrees(0))
                            .animation(.default, value: datePickerPresented)
                    }
                }
                .padding(21)
                .foregroundStyle(.textPrimary)
                .onTapGesture {
                    newDate = month
                    datePickerPresented = true
                }
                
                Spacer()
                
                Button {
                    onSelectDate(.now)
                } label: {
                    Text("오늘")
                        .font(.medium_16)
                        .padding(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .frame(height: 44)
                
                Menu {
                    NavigationLink {
                        NotificationSettingView(viewModel: notificationViewModel)
                    } label: {
                        Label("알림 설정", systemImage: "bell.fill")
                    }
                    
                    NavigationLink {
                        AppearanceSettingView(viewModel: appearanceViewModel)
                    } label: {
                        Label("화면 테마", systemImage: "circle.lefthalf.filled")
                    }

                    NavigationLink {
                        CalendarSharingSettingView(viewModel: calendarSharingViewModel)
                    } label: {
                        Label("캘린더 연결", systemImage: "person.2.fill")
                    }
                    
                    NavigationLink {
                        PeriodSettingView(viewModel: periodSettingViewModel)
                    } label: {
                        Label("생리 주기 설정", systemImage: "drop.fill")
                    }
                    
                    NavigationLink {
                        PillSettingView(viewModel: pillViewModel)
                    } label: {
                        Label("피임약 설정", image: .pillSettingIcon)
                    }
                    
                    NavigationLink {
                        AppleCalendarSettingView(viewModel: appleCalendarViewModel)
                    } label: {
                        Label("Apple Calendar", systemImage: "apple.logo")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.icon)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .frame(width: 44, height: 44)
                .padding(.trailing, 16)
            }
            
            HStack(spacing: 0) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) {
                    Text($0)
                        .font(.medium_11)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 5)
            
            Rectangle()
                .fill(.black.opacity(0.12))
                .frame(height: 1.2)
                .offset(y: 0.6)
        }
        .sheet(isPresented: $datePickerPresented) {
            NavigationStack {
                DatePicker("", selection: $newDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.init(top: 18, leading: 12, bottom: 18, trailing: 12))
                    .background(RoundedRectangle(cornerRadius: 20).fill(.bgSecondary))
                    .padding(.init(top: 0, leading: 16, bottom: 42, trailing: 16))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                datePickerPresented = false
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        ToolbarItem(placement: .title) {
                            Text("날짜")
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) {
                                onSelectDate(newDate)
                                datePickerPresented = false
                            } label: {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.bgSecondary)
                            }
                            .tint(.mainRed)
                            .buttonStyle(.glassProminent)
                        }
                    }
            }
            .appGradientOverlay()
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        
    }
}

#Preview {
    CalendarHeaderView(
        month: .now,
        onSelectDate: { _ in },
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
        )
    )
}
