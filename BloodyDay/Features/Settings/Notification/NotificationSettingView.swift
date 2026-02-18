//
//  NotificationSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/11/25.
//

import SwiftUI
import UserNotifications
import UIKit

struct NotificationSettingView: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @State private var activeSheet: NotificationSheet?
    @State private var isSystemNotificationOff: Bool = false
    
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
                                Text("시작 예정일 \(dayLabel(notifications.periodReminderDaysBefore)) \(formatTime(notifications.periodReminderTime))")
                                    .font(.regular_14)
                                    .foregroundStyle(notifications.periodReminderEnabled ? .mainRed : .textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Toggle("", isOn: notificationBinding(\.periodReminderEnabled, sheet: .periodReminder))
                            .labelsHidden()
                    }
                    
                    if notifications.periodReminderEnabled {
                        HStack {
                            Text("생리 지연")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Toggle("", isOn: notificationBinding(\.periodDelayedEnabled, sheet: nil))
                                .labelsHidden()
                        }
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.mainRed)
                
                Section(footer: footerMessage) {
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
                                Text("복용 예정일 \(dayLabel(notifications.pillPurchaseReminderDaysBefore)) \(formatTime(notifications.pillPurchaseReminderTime))")
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
            .animation(.easeInOut(duration: 0.2), value: notifications.periodReminderEnabled)
            .disabled(isSystemNotificationOff)
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .appGradientOverlay()
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("알림")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshSystemNotificationState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshSystemNotificationState()
        }
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
            .appGradientOverlay(sheet.gradientStyle)
        }
    }
    
    @ViewBuilder
    private var footerMessage: some View {
        if isSystemNotificationOff {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 100)
                    .fill(.mainRed10)
                    .frame(height: 40)
                
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .regular))
                    
                    Text("푸시 알림을 받으려면 알림 허용이 필요합니다.")
                        .font(.regular_14)
                }
                .foregroundStyle(.mainRed)
                .padding(.horizontal, 16)
            }
            .padding(.top, 14)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
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
    
    private func refreshSystemNotificationState() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let enabled: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                enabled = true
            case .denied, .notDetermined:
                enabled = false
            @unknown default:
                enabled = false
            }
            DispatchQueue.main.async {
                isSystemNotificationOff = !enabled
            }
        }
    }
}

private enum NotificationSheet: Int, Identifiable {
    case periodReminder
    case pillReminder
    case pillPurchaseReminder
    
    var id: Int { rawValue }

    var gradientStyle: AppGradientOverlayStyle {
        switch self {
        case .periodReminder:
            return .default
        case .pillReminder, .pillPurchaseReminder:
            return .blue
        }
    }
}

private func dayLabel(_ daysBefore: Int) -> String {
    switch daysBefore {
    case 0:
        return "당일"
    case 1:
        return "하루 전"
    case 2:
        return "이틀 전"
    default:
        return "\(daysBefore)일 전"
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
