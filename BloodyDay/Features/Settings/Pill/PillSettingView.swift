//
//  PillSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/12/25.
//

import SwiftUI

struct PillSettingView: View {
    @Bindable var viewModel: PillSettingsViewModel
    
    var body: some View {
        VStack {
            List {
                Section {
                    Toggle(isOn: pillBinding(\.pillEnabled)) {
                        Text("경구 피임약 복용")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.subBlue)
                
                if viewModel.settings.pill.pillEnabled {
                    Section {
                        Toggle(isOn: pillBinding(\.pillCalendarCalculationEnabled)) {
                            Text("피임약 기반 생리 주기 계산")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                        }
                        
                        Toggle(isOn: pillBinding(\.pillAutoRecordEnabled)) {
                            Text("캘린더에 복용일 자동 기록")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subBlue)
                    
                    Section {
                        HStack(spacing: 1) {
                            Text("피임약 개수")
                            
                            Group {
                                TextField("", text: pillCountBinding())
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                Text("정")
                            }
                            .foregroundStyle(.subBlue)
                        }
                        
                        HStack(spacing: 1) {
                            Text("휴약 기간")
                            
                            Group {
                                TextField("", text: pillBreakBinding())
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                Text("일")
                            }
                            .foregroundStyle(.subBlue)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subBlue)
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
                Text("피임약")
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func pillBinding(_ keyPath: WritableKeyPath<PillSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings.pill[keyPath: keyPath] },
            set: { value in
                viewModel.updatePill { $0[keyPath: keyPath] = value }
            }
        )
    }
    
    private func pillCountBinding() -> Binding<String> {
        Binding(
            get: { String(viewModel.settings.pill.pillCount) },
            set: { value in
                guard let intValue = Int(value) else { return }
                viewModel.updatePill { $0.pillCount = intValue }
            }
        )
    }
    
    private func pillBreakBinding() -> Binding<String> {
        Binding(
            get: { String(viewModel.settings.pill.pillBreakDuration) },
            set: { value in
                guard let intValue = Int(value) else { return }
                viewModel.updatePill { $0.pillBreakDuration = intValue }
            }
        )
    }
}

#Preview {
    NavigationStack {
        PillSettingView(viewModel: .init(repo: UserDefaultsSettingsRepository()))
    }
}
