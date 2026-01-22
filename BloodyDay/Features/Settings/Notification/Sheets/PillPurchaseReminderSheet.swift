//
//  PillPurchaseReminderSheet.swift
//  BloodyDay
//
//  Created by Yunki on 1/22/26.
//

import SwiftUI

struct PillPurchaseReminderSheet: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var reminderTime: Date = Date()
    
    private let options: [(label: String, daysBefore: Int)] = [
        ("새 피임약 복용 이틀 전", 2),
        ("새 피임약 복용 하루 전", 1),
        ("새 피임약 복용 당일", 0)
    ]
    
    var body: some View {
        List {
            Section {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button {
                        withAnimation {
                            updateDaysBefore(option.daysBefore)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: option.daysBefore == selectedDaysBefore ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(option.daysBefore == selectedDaysBefore ? .subBlue : .textQuaternary)
                                .font(.system(size: 18))
                            Text(option.label)
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if option.daysBefore == selectedDaysBefore {
                        DatePicker(
                            "",
                            selection: $reminderTime,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    }
                }
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
                Text("피임약 구매 알림 설정")
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
    
    private var selectedDaysBefore: Int {
        viewModel.settings.notifications.pillPurchaseReminderDaysBefore
    }
    
    private func updateDaysBefore(_ value: Int) {
        viewModel.updateNotifications { $0.pillPurchaseReminderDaysBefore = value }
    }
    
    private func timeFromSettings() -> Date {
        let now = Date()
        let components = viewModel.settings.notifications.pillPurchaseReminderTime
        let hour = components.hour ?? 16
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
            $0.pillPurchaseReminderTime = components
        }
    }
}

#Preview {
    NavigationStack {
        PillPurchaseReminderSheet(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                scheduler: NoopNotificationScheduler(),
                eventRepository: MockEventRepository()
            )
        )
    }
}
