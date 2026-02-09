//
//  AppleCalendarSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/12/25.
//

import SwiftUI

struct AppleCalendarSettingView: View {
    @Bindable var viewModel: AppleCalendarSettingViewModel
    
    var body: some View {
        let isEnabled = Binding(
            get: { viewModel.settings.appleCalendar.isEnabled },
            set: { value in
                Task { await viewModel.setEnabled(value) }
            }
        )
        VStack {
            List {
                Section {
                    Toggle(isOn: isEnabled) {
                        Text("Apple Calendar 연결")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                    .tint(.mainRed)
                }
                .listRowBackground(Color.bgSecondary)
                
                if viewModel.settings.appleCalendar.isEnabled {
                    Section {
                        Toggle(isOn: eventToggleBinding(.period)) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.mainRed)
                                Text("생리 기록 연결")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        if viewModel.isEventEnabled(.period) {
                            TextField(
                                "",
                                text: calendarNameBinding(.period),
                                prompt: Text("🩸B-Day")
                                    .font(.regular_18)
                                    .foregroundColor(.textPrimary)
                            )
                            .opacity(viewModel.calendarNameInput(for: .period).isEmpty ? 0.15 : 1)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.mainRed)
                    
                    Section {
                        Toggle(isOn: eventToggleBinding(.pill)) {
                            HStack {
                                Image(.pillHalf)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.subBlue)
                                Text("피임약 기록 연결")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        if viewModel.isEventEnabled(.pill) {
                            TextField(
                                "",
                                text: calendarNameBinding(.pill),
                                prompt: Text("💊피임약 복용")
                                    .font(.regular_18)
                                    .foregroundColor(.textPrimary)
                            )
                            .opacity(viewModel.calendarNameInput(for: .pill).isEmpty ? 0.15 : 1)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subBlue)
                    
                    Section {
                        Toggle(isOn: eventToggleBinding(.love)) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.subPink)
                                Text("사랑한 날 기록 연결")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        if viewModel.isEventEnabled(.love) {
                            TextField(
                                "",
                                text: calendarNameBinding(.love),
                                prompt: Text("💗사랑한 날")
                                    .font(.regular_18)
                                    .foregroundColor(.textPrimary)
                            )
                            .opacity(viewModel.calendarNameInput(for: .love).isEmpty ? 0.15 : 1)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subPink)
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
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("Apple Calendar")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func eventToggleBinding(_ type: EventType) -> Binding<Bool> {
        Binding(
            get: { viewModel.isEventEnabled(type) },
            set: { value in
                Task { await viewModel.setEventEnabled(type, value) }
            }
        )
    }

    private func calendarNameBinding(_ type: EventType) -> Binding<String> {
        Binding(
            get: { viewModel.calendarNameInput(for: type) },
            set: { value in
                Task { await viewModel.setCalendarName(type, value) }
            }
        )
    }
}

#Preview {
    NavigationStack {
        AppleCalendarSettingView(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                calendarClient: NoopAppleCalendarClient(),
                syncService: AppleCalendarSyncService(
                    settingsRepository: UserDefaultsSettingsRepository(),
                    eventRepository: MockEventRepository(),
                    calendarClient: NoopAppleCalendarClient(),
                    syncStore: UserDefaultsAppleCalendarSyncStore()
                )
            )
        )
    }
}
