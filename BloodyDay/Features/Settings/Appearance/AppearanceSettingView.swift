//
//  AppearanceSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 4/12/26.
//

import SwiftUI

struct AppearanceSettingView: View {
    @Bindable var viewModel: AppearanceSettingViewModel
    
    var body: some View {
        VStack {
            List {
                Section {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Button {
                            withAnimation {
                                viewModel.select(appearance)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.selectedAppearance == appearance ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedAppearance == appearance ? .mainRed : .textQuaternary)
                                    .font(.system(size: 18))
                                
                                Text(appearance.displayName)
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
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
                Text("화면 테마")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension AppAppearance {
    var displayName: String {
        switch self {
        case .system:
            return "시스템 테마"
        case .light:
            return "라이트 테마"
        case .dark:
            return "다크 테마"
        }
    }
}

#Preview {
    AppearanceSettingView(viewModel: .init(repo: UserDefaultsSettingsRepository()))
}
