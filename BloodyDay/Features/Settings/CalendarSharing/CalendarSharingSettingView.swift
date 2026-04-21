//
//  CalendarSharingSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import SwiftUI

struct CalendarSharingSettingView: View {
    @Bindable var viewModel: CalendarSharingSettingViewModel
    
    var body: some View {
        VStack {
            List {
                Section {
                    HStack {
                        Text("iCloud 상태")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                        
                        Spacer()
                        
                        Text(viewModel.iCloudStatusText)
                            .font(.regular_16)
                            .foregroundStyle(viewModel.isICloudAvailable ? .subBlue : .textSecondary40)
                    }
                } footer: {
                    Text("iCloud 계정 상태를 확인해 공유 기능 가능 여부를 표시합니다.")
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                        .padding(.top, 14)
                }
                .listRowBackground(Color.bgSecondary)
                
                Section {
                    scopeRow(
                        title: "내 캘린더",
                        isSelected: viewModel.isSelected(.mine)
                    ) {
                        viewModel.selectMine()
                    }
                    
                    ForEach(viewModel.sharedCalendars) { calendar in
                        scopeRow(
                            title: calendar.displayName,
                            subtitle: sharedCalendarSummary(for: calendar),
                            isSelected: viewModel.isSelected(.shared(id: calendar.id)),
                            accessory: {
                                Button {
                                    viewModel.manage(calendarId: calendar.id)
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.textSecondary40)
                                }
                                .buttonStyle(.plain)
                            }
                        ) {
                            viewModel.selectSharedCalendar(id: calendar.id)
                        }
                    }
                } header: {
                    Text("현재 보고 있는 캘린더")
                } footer: {
                    Text("선택한 캘린더가 메인 캘린더 화면에 표시됩니다.")
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                        .padding(.top, 14)
                }
                .listRowBackground(Color.bgSecondary)
                
                Section {
                    sharingTypeRow(
                        title: "생리",
                        isOn: Binding(
                            get: { viewModel.sharedEventTypeSelection.period },
                            set: { viewModel.setSharedEventType(.period, enabled: $0) }
                        ),
                        tint: .mainRed
                    )
                    sharingTypeRow(
                        title: "피임약 복용",
                        isOn: Binding(
                            get: { viewModel.sharedEventTypeSelection.pill },
                            set: { viewModel.setSharedEventType(.pill, enabled: $0) }
                        ),
                        tint: .subBlue
                    )
                    sharingTypeRow(
                        title: "사랑한 날",
                        isOn: Binding(
                            get: { viewModel.sharedEventTypeSelection.love },
                            set: { viewModel.setSharedEventType(.love, enabled: $0) }
                        ),
                        tint: .subPink
                    )
                } header: {
                    Text("내 캘린더 공유")
                } footer: {
                    Text("선택한 항목을 기준으로 CloudKit 공유 레코드에 업로드할 예정입니다.")
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                        .padding(.top, 14)
                }
                .listRowBackground(Color.bgSecondary)
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 14)
            .scrollContentBackground(.hidden)
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .appGradientOverlay()
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("캘린더 공유")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.reload()
            viewModel.refreshICloudAvailability()
        }
        .onReceive(NotificationCenter.default.publisher(for: CloudKitSharingService.acceptedShareNotification)) { _ in
            viewModel.reload()
        }
        .sheet(item: $viewModel.managingCalendar) { calendar in
            managingSheet(for: calendar)
        }
    }
    
    private func scopeRow(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        @ViewBuilder accessory: () -> some View = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .mainRed : .textQuaternary)
                .font(.system(size: 18))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.regular_18)
                    .foregroundStyle(.textPrimary)
                
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                }
            }
            
            Spacer()
            
            accessory()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
    
    private func sharingTypeRow(title: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.regular_18)
                .foregroundStyle(.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(tint)
        }
    }
    
    private func sharedEventTypeText(for selection: SharedEventTypeSelection) -> String {
        let labels = [
            selection.period ? "생리" : nil,
            selection.pill ? "피임약" : nil,
            selection.love ? "사랑한 날" : nil
        ]
        .compactMap { $0 }
        
        return labels.isEmpty ? "공유 항목 없음" : labels.joined(separator: ", ")
    }
    
    private func sharedCalendarSummary(for calendar: SharedCalendar) -> String {
        "\(sharedEventTypeText(for: calendar.sharedEventTypes)) · \(permissionText(for: calendar.permission))"
    }
    
    private func permissionText(for permission: SharedCalendarPermission) -> String {
        switch permission {
        case .readOnly:
            return "읽기 전용"
        case .readWrite:
            return "편집 가능"
        }
    }
    
    @ViewBuilder
    private func managingSheet(for calendar: SharedCalendar) -> some View {
        NavigationStack {
            List {
                Section {
                    detailRow(title: "이름", value: calendar.displayName)
                    detailRow(title: "공유 항목", value: sharedEventTypeText(for: calendar.sharedEventTypes))
                    detailRow(title: "권한", value: permissionText(for: calendar.permission))
                } footer: {
                    Text("이름 변경과 공유 나가기는 CloudKit 연동 단계에서 추가됩니다.")
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                        .padding(.top, 14)
                }
                .listRowBackground(Color.bgSecondary)
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 14)
            .scrollContentBackground(.hidden)
            .background {
                Color.bgPrimary
                    .ignoresSafeArea()
            }
            .appGradientOverlay()
            .navigationTitle(calendar.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        viewModel.dismissManagement()
                    }
                    .foregroundStyle(.mainRed)
                }
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.regular_18)
                .foregroundStyle(.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.regular_16)
                .foregroundStyle(.textSecondary40)
        }
    }
}

#Preview {
    NavigationStack {
        CalendarSharingSettingView(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                sharedCalendarRepository: MockSharedCalendarRepository(),
                cloudSharingService: CloudKitSharingService()
            )
        )
    }
}
