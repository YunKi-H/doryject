//
//  NotificationSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/11/25.
//

import SwiftUI

struct NotificationSettingView: View {
    @State private var periodDueDateNotify: Bool = false
    @State private var periodDelayedNotify: Bool = false
    
    @State private var pillTakingNotify: Bool = false
    @State private var pillBuyingNotify: Bool = false
    
    var body: some View {
        VStack {
            List {
                Section {
                    Toggle(isOn: $periodDueDateNotify) {
                        VStack(alignment: .leading) {
                            Text("생리 예정일")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Text("시작 예정일 이틀 전 09:00")
                                .font(.regular_14)
                                .foregroundStyle(periodDueDateNotify ? .mainRed : .textTertiary)
                        }
                    }
                    
                    Toggle(isOn: $periodDelayedNotify) {
                        Text("생리 지연")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.mainRed)
                
                Section {
                    Toggle(isOn: $pillTakingNotify) {
                        VStack(alignment: .leading) {
                            Text("피임약 복용")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Text("매일 12:40")
                                .font(.regular_14)
                                .foregroundStyle(pillTakingNotify ? .subBlue : .textTertiary)
                        }
                    }
                    
                    Toggle(isOn: $pillBuyingNotify) {
                        VStack(alignment: .leading) {
                            Text("피임약 구매")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Text("복용 예정일 하루 전 16:00")
                                .font(.regular_14)
                                .foregroundStyle(pillBuyingNotify ? .subBlue : .textTertiary)
                        }
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.subBlue)
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 14)
            .scrollContentBackground(.hidden)
        }
        .background(Color.bgPrimary)
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("알림")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingView()
    }
}
