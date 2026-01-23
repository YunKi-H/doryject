//
//  NotificationSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/11/25.
//

import SwiftUI

struct NotificationSettingView: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @State private var activeSheet: NotificationSheet?
    
    var body: some View {
        let notifications = viewModel.settings.notifications
        VStack {
            List {
                Section {
                    HStack {
                        Button {
                            openSheet(.periodReminder, enableKeyPath: \.periodReminderEnabled)
                        } label: {
                            VStack(alignment: .leading) {
                                Text("생리 예정일")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                                Text("시작 예정일 \(notifications.periodReminderDaysBefore)일 전 \(formatTime(notifications.periodReminderTime))")
                                    .font(.regular_14)
                                    .foregroundStyle(notifications.periodReminderEnabled ? .mainRed : .textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Toggle("", isOn: notificationBinding(\.periodReminderEnabled, sheet: .periodReminder))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("생리 지연")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Toggle("", isOn: notificationBinding(\.periodDelayedEnabled, sheet: nil))
                            .labelsHidden()
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.mainRed)
                
                Section {
                    HStack {
                        Button {
                            openSheet(.pillReminder, enableKeyPath: \.pillReminderEnabled)
                        } label: {
                            VStack(alignment: .leading) {
                                Text("피임약 복용")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                                Text("매일 \(formatTime(notifications.pillReminderTime))")
                                    .font(.regular_14)
                                    .foregroundStyle(notifications.pillReminderEnabled ? .subBlue : .textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Toggle("", isOn: notificationBinding(\.pillReminderEnabled, sheet: .pillReminder))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Button {
                            openSheet(.pillPurchaseReminder, enableKeyPath: \.pillPurchaseReminderEnabled)
                        } label: {
                            VStack(alignment: .leading) {
                                Text("피임약 구매")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                                Text("복용 예정일 \(notifications.pillPurchaseReminderDaysBefore)일 전 \(formatTime(notifications.pillPurchaseReminderTime))")
                                    .font(.regular_14)
                                    .foregroundStyle(notifications.pillPurchaseReminderEnabled ? .subBlue : .textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Toggle("", isOn: notificationBinding(\.pillPurchaseReminderEnabled, sheet: .pillPurchaseReminder))
                            .labelsHidden()
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
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .periodReminder:
                    PeriodReminderSheet(viewModel: viewModel)
                case .pillReminder:
                    PillReminderSheet(viewModel: viewModel)
                case .pillPurchaseReminder:
                    PillPurchaseReminderSheet(viewModel: viewModel)
                }
            }
        }
    }

    private func notificationBinding(
        _ keyPath: WritableKeyPath<NotificationSettings, Bool>,
        sheet: NotificationSheet?
    ) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings.notifications[keyPath: keyPath] },
            set: { value in
                viewModel.updateNotifications { $0[keyPath: keyPath] = value }
                if value, let sheet {
                    activeSheet = sheet
                }
            }
        )
    }

    private func openSheet(
        _ sheet: NotificationSheet,
        enableKeyPath: WritableKeyPath<NotificationSettings, Bool>
    ) {
        if viewModel.settings.notifications[keyPath: enableKeyPath] == false {
            viewModel.updateNotifications { $0[keyPath: enableKeyPath] = true }
        }
        activeSheet = sheet
    }

    private func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}

private enum NotificationSheet: Int, Identifiable {
    case periodReminder
    case pillReminder
    case pillPurchaseReminder
    
    var id: Int { rawValue }
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
