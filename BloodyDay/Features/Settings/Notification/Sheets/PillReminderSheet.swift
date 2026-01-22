//
//  PillReminderSheet.swift
//  BloodyDay
//
//  Created by Yunki on 1/22/26.
//

import SwiftUI

struct PillReminderSheet: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var reminderTime: Date = Date()
    
    var body: some View {
        List {
            Section {
                Button {
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.subBlue)
                            .font(.system(size: 18))
                        Text("매일")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                
                DatePicker(
                    "",
                    selection: $reminderTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .listRowBackground(Color.bgSecondary)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .contentMargins(.top, 14)
        .scrollContentBackground(.hidden)
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .onAppear {
            reminderTime = timeFromSettings()
        }
        .onChange(of: reminderTime) { _, newValue in
            updateTime(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("피임약 복용 알림 설정")
                    .font(.semibold_18)
                    .foregroundStyle(.textPrimary)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(.glassProminent)
                .tint(.subBlue)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func timeFromSettings() -> Date {
        let now = Date()
        let components = viewModel.settings.notifications.pillReminderTime
        let hour = components.hour ?? 9
        let minute = components.minute ?? 0
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) ?? now
    }
    
    private func updateTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        viewModel.updateNotifications {
            $0.pillReminderTime = components
        }
    }
}

#Preview {
    NavigationStack {
        PillReminderSheet(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                scheduler: NoopNotificationScheduler(),
                eventRepository: MockEventRepository()
            )
        )
    }
}
