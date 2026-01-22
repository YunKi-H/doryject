//
//  NotificationSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/11/25.
//

import SwiftUI

struct NotificationSettingView: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    
    var body: some View {
        let notifications = viewModel.settings.notifications
        VStack {
            List {
                Section {
                    Toggle(isOn: notificationBinding(\.periodReminderEnabled)) {
                        VStack(alignment: .leading) {
                            Text("생리 예정일")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Text("시작 예정일 \(notifications.periodReminderDaysBefore)일 전 \(formatTime(notifications.periodReminderTime))")
                                .font(.regular_14)
                                .foregroundStyle(notifications.periodReminderEnabled ? .mainRed : .textTertiary)
                        }
                    }
                    
                    Toggle(isOn: notificationBinding(\.periodDelayedEnabled)) {
                        Text("생리 지연")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.mainRed)
                
                Section {
                    Toggle(isOn: notificationBinding(\.pillReminderEnabled)) {
                        VStack(alignment: .leading) {
                            Text("피임약 복용")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Text("매일 \(formatTime(notifications.pillReminderTime))")
                                .font(.regular_14)
                                .foregroundStyle(notifications.pillReminderEnabled ? .subBlue : .textTertiary)
                        }
                    }
                    
                    Toggle(isOn: notificationBinding(\.pillPurchaseReminderEnabled)) {
                        VStack(alignment: .leading) {
                            Text("피임약 구매")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Text("복용 예정일 \(notifications.pillPurchaseReminderDaysBefore)일 전 \(formatTime(notifications.pillPurchaseReminderTime))")
                                .font(.regular_14)
                                .foregroundStyle(notifications.pillPurchaseReminderEnabled ? .subBlue : .textTertiary)
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
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("알림")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func notificationBinding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings.notifications[keyPath: keyPath] },
            set: { value in
                viewModel.updateNotifications { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingView(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                scheduler: NoopNotificationScheduler(),
                eventRepository: MockEventRepository()
            )
        )
    }
}
