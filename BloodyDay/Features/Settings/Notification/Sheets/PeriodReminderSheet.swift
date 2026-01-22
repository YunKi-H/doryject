//
//  PeriodReminderSheet.swift
//  BloodyDay
//
//  Created by Yunki on 1/22/26.
//

import SwiftUI

struct PeriodReminderSheet: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var reminderTime: Date = Date()
    
    private let options: [(label: String, daysBefore: Int)] = [
        ("시작 예정일 이틀 전", 2),
        ("시작 예정일 하루 전", 1),
        ("시작 예정일 당일", 0)
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
                                .foregroundStyle(option.daysBefore == selectedDaysBefore ? .mainRed : .textQuaternary)
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
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            
            ToolbarItem(placement: .title) {
                Text("생리 예정일 알림 설정")
                    .font(.semibold_18)
                    .foregroundStyle(.textPrimary)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(.glassProminent)
                .tint(.mainRed)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var selectedDaysBefore: Int {
        viewModel.settings.notifications.periodReminderDaysBefore
    }
    
    private func updateDaysBefore(_ value: Int) {
        viewModel.updateNotifications { $0.periodReminderDaysBefore = value }
    }
    
    private func timeFromSettings() -> Date {
        let now = Date()
        let components = viewModel.settings.notifications.periodReminderTime
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
            $0.periodReminderTime = components
        }
    }
}


#Preview {
    NavigationStack {
        PeriodReminderSheet(
            viewModel: .init(
                repo: UserDefaultsSettingsRepository(),
                scheduler: NoopNotificationScheduler(),
                eventRepository: MockEventRepository()
            )
        )
    }
}
