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
                        
                        Text(viewModel.isICloudAvailable ? "사용 가능" : "준비 중")
                            .font(.regular_16)
                            .foregroundStyle(.textSecondary40)
                    }
                } footer: {
                    Text("CloudKit 공유 연동 전 단계입니다.")
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
                            isSelected: viewModel.isSelected(.shared(id: calendar.id))
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
                    sharingTypeRow(title: "생리", enabled: viewModel.sharedEventTypeSelection.period, tint: .mainRed)
                    sharingTypeRow(title: "피임약 복용", enabled: viewModel.sharedEventTypeSelection.pill, tint: .subBlue)
                    sharingTypeRow(title: "사랑한 날", enabled: viewModel.sharedEventTypeSelection.love, tint: .subPink)
                } header: {
                    Text("내 캘린더 공유")
                } footer: {
                    Text("공유할 이벤트 타입 선택은 CloudKit 연동 단계에서 활성화됩니다.")
                        .font(.regular_14)
                        .foregroundStyle(.textSecondary40)
                        .padding(.top, 14)
                }
                .listRowBackground(Color.bgSecondary)
                
                if viewModel.sharedCalendars.isEmpty == false {
                    Section {
                        ForEach(viewModel.sharedCalendars) { calendar in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(calendar.displayName)
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                                
                                Text(sharedEventTypeText(for: calendar.sharedEventTypes))
                                    .font(.regular_14)
                                    .foregroundStyle(.textSecondary40)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("받은 캘린더")
                    }
                    .listRowBackground(Color.bgSecondary)
                }
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
        }
    }
    
    private func scopeRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .mainRed : .textQuaternary)
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.regular_18)
                    .foregroundStyle(.textPrimary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func sharingTypeRow(title: String, enabled: Bool, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.regular_18)
                .foregroundStyle(.textPrimary)
            
            Spacer()
            
            Text(enabled ? "ON" : "OFF")
                .font(.regular_16)
                .foregroundStyle(tint.opacity(enabled ? 1 : 0.35))
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
}

#Preview {
    NavigationStack {
        CalendarSharingSettingView(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                sharedCalendarRepository: MockSharedCalendarRepository()
            )
        )
    }
}
