//
//  PillSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/12/25.
//

import SwiftUI

struct PillSettingView: View {
    @Bindable var viewModel: PillSettingsViewModel
    
    @FocusState private var focusedField: PillSettingField?
    
    private enum PillSettingField: Hashable {
        case pillCount
        case pillBreak
        
        var message: String {
            switch self {
            case .pillCount: return "일반적인 경구 피임약 한 팩의 개수는  21~35정입니다."
            case .pillBreak: return "일반적인 경구 피임약의 휴약 기간은 4~7일입니다."
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: pillBinding(\.pillEnabled)) {
                    Text("경구 피임약 복용")
                        .font(.regular_18)
                        .foregroundStyle(.textPrimary)
                }

                Toggle(isOn: pillBinding(\.pillAutoRecordEnabled)) {
                    Text("캘린더에 복용일 자동 기록")
                        .font(.regular_18)
                        .foregroundStyle(.textPrimary)
                }
                .disabled(!viewModel.settings.pill.pillEnabled)
            }
            .listRowBackground(Color.bgSecondary)
            .tint(.subBlue)
            
            Section(footer: footerMessage) {
                HStack(spacing: 1) {
                    Text("피임약 개수")
                    
                    Group {
                        TextField("", text: pillCountBinding())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .pillCount)
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
                            .focused($focusedField, equals: .pillBreak)
                        Text("일")
                    }
                    .foregroundStyle(.subBlue)
                }
            }
            .listRowBackground(Color.bgSecondary)
            .tint(.subBlue)
        }
        .listSectionSpacing(14)
        .contentMargins(.top, 14)
        .scrollContentBackground(.hidden)
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .appGradientOverlay(.blue)
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("피임약")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.reload()
        }
    }
    
    @ViewBuilder
    private var footerMessage: some View {
        if let focused = focusedField {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 100)
                    .fill(.subBlue)
                    .opacity(0.07)
                    .frame(height: 40)
                
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .regular))
                    
                    Text(focused.message)
                        .font(.regular_14)
                }
                .foregroundStyle(.subBlue)
                .padding(.horizontal, 16)
            }
            .padding(.top, 14)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
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
