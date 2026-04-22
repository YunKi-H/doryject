//
//  CalendarSharingSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import SwiftUI

struct CalendarSharingSettingView: View {
    @Bindable var viewModel: CalendarSharingSettingViewModel
    @State private var isShowingStopOwnedSharingConfirmation = false
    @State private var calendarPendingLeave: SharedCalendar?
    
    var body: some View {
        VStack {
            List {
                iCloudStatusSection
                calendarScopeSection
                ownCalendarSharingSection
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
            viewModel.refreshICloudAvailability()
            viewModel.refreshOwnedShareState()
            Task {
                await viewModel.refreshSharedCalendars()
            }
        }
        .onDisappear {
            viewModel.dismissShareSheet()
        }
        .sheet(item: $viewModel.managingCalendar) { calendar in
            managingSheet(for: calendar)
        }
        .background {
            if let sharePresentationID = viewModel.sharePresentationID {
                CloudSharingControllerPresenter(
                    existingShare: viewModel.preparedShare,
                    containerIdentifier: viewModel.cloudContainerIdentifier,
                    shouldPresentOnAppear: viewModel.shouldPresentShareController(for: sharePresentationID),
                    prepareShare: {
                        try await viewModel.prepareOwnedShare()
                    },
                    onDidPresent: {
                        viewModel.markShareControllerPresented(id: sharePresentationID)
                    },
                    onDidDismiss: {
                        viewModel.dismissShareSheet()
                    },
                    onDidSaveShare: {
                        viewModel.dismissShareSheet()
                        viewModel.refreshOwnedShareState()
                        Task {
                            await viewModel.refreshSharedCalendars()
                        }
                    },
                    onDidStopSharing: {
                        viewModel.dismissShareSheet()
                        viewModel.refreshOwnedShareState()
                        Task {
                            await viewModel.refreshSharedCalendars()
                        }
                    },
                    onDidFailToSaveShare: { error in
                        viewModel.handleSharePreparationFailure(error)
                    }
                )
                .id(sharePresentationID)
                .frame(width: 0, height: 0)
            }
        }
        .alert(
            "공유를 시작할 수 없어요",
            isPresented: Binding(
                get: { viewModel.sharePresentationErrorMessage != nil },
                set: { if $0 == false { viewModel.dismissSharePresentationError() } }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.dismissSharePresentationError()
            }
        } message: {
            Text(viewModel.sharePresentationErrorMessage ?? "")
        }
        .confirmationDialog(
            "내 캘린더 공유를 중단할까요?",
            isPresented: $isShowingStopOwnedSharingConfirmation,
            titleVisibility: .visible
        ) {
            Button("공유 중단", role: .destructive) {
                Task {
                    await viewModel.stopOwnedSharing()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("공유 링크와 공유된 이벤트가 iCloud에서 제거됩니다. 이미 초대받은 사람도 더 이상 내 캘린더를 볼 수 없습니다.")
        }
        .confirmationDialog(
            "공유 캘린더에서 나갈까요?",
            isPresented: isShowingLeaveSharedCalendarConfirmation,
            titleVisibility: .visible
        ) {
            Button("공유 나가기", role: .destructive) {
                guard let calendar = calendarPendingLeave else { return }
                Task {
                    await viewModel.leaveSharedCalendar(calendar)
                }
            }
            Button("취소", role: .cancel) {
                calendarPendingLeave = nil
            }
        } message: {
            Text(leaveSharedCalendarMessage)
        }
    }
    
    private var isShowingLeaveSharedCalendarConfirmation: Binding<Bool> {
        Binding(
            get: { calendarPendingLeave != nil },
            set: { isPresented in
                if isPresented == false {
                    calendarPendingLeave = nil
                }
            }
        )
    }
    
    private var leaveSharedCalendarMessage: String {
        guard let calendarPendingLeave else {
            return "공유 캘린더가 목록에서 제거됩니다."
        }
        return "\(calendarPendingLeave.displayName) 캘린더가 목록에서 제거됩니다."
    }
    
    private var iCloudStatusSection: some View {
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
    }
    
    private var calendarScopeSection: some View {
        Section {
            scopeRow(
                title: "내 캘린더",
                isSelected: viewModel.isSelected(.mine)
            ) {
                viewModel.selectMine()
            }
            
            ForEach(viewModel.sharedCalendars) { calendar in
                sharedCalendarScopeRow(calendar)
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
    }
    
    private var ownCalendarSharingSection: some View {
        Section {
            sharingTypeRows
            shareManagementButton
            if viewModel.hasOwnedShare {
                stopOwnedSharingButton
            }
        } header: {
            Text("내 캘린더 공유")
        } footer: {
            ownCalendarSharingFooter
        }
        .listRowBackground(Color.bgSecondary)
    }
    
    private var sharingTypeRows: some View {
        Group {
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
        }
    }
    
    private var shareManagementButton: some View {
        Button {
            viewModel.presentShareSheet()
        } label: {
            HStack {
                Text(viewModel.isPreparingShare ? "공유 준비 중" : "공유 시작 / 관리")
                    .font(.regular_18)
                    .foregroundStyle(.textPrimary)
                
                Spacer()
                
                if viewModel.isPreparingShare {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary40)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPreparingShare || viewModel.isChangingShareState)
    }
    
    private var stopOwnedSharingButton: some View {
        Button(role: .destructive) {
            isShowingStopOwnedSharingConfirmation = true
        } label: {
            HStack {
                Text(viewModel.isChangingShareState ? "처리 중" : "내 캘린더 공유 중단")
                    .font(.regular_18)
                
                Spacer()
                
                if viewModel.isChangingShareState {
                    ProgressView()
                }
            }
        }
        .disabled(viewModel.isPreparingShare || viewModel.isChangingShareState)
    }
    
    private var ownCalendarSharingFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("선택한 항목을 기준으로 CloudKit 공유 레코드에 업로드할 예정입니다.")
                .foregroundStyle(.textSecondary40)
            
            if let eventSyncWarningMessage = viewModel.eventSyncWarningMessage {
                Text(eventSyncWarningMessage)
                    .foregroundStyle(.mainRed)
            }
        }
        .font(.regular_14)
        .padding(.top, 14)
    }
    
    private func sharedCalendarScopeRow(_ calendar: SharedCalendar) -> some View {
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
                }
                .listRowBackground(Color.bgSecondary)
                
                Section {
                    Button(role: .destructive) {
                        calendarPendingLeave = calendar
                    } label: {
                        HStack {
                            Text(viewModel.isChangingShareState ? "처리 중" : "공유 나가기")
                                .font(.regular_18)
                            
                            Spacer()
                            
                            if viewModel.isChangingShareState {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isChangingShareState)
                } footer: {
                    Text("이 기기에서 공유 캘린더를 제거하고 iCloud 공유 참여를 해제합니다.")
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
                eventRepository: MockEventRepository(),
                sharedCalendarRepository: MockSharedCalendarRepository(),
                cloudSharingService: CloudKitSharingService()
            )
        )
    }
}
