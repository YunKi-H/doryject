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
    @State private var selectedDaysBefore: Int = 0
    
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
                            selectedDaysBefore = option.daysBefore
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
            let settings = viewModel.settings.notifications
            selectedDaysBefore = settings.pillPurchaseReminderDaysBefore
            reminderTime = timeFromSettings(settings.pillPurchaseReminderTime, fallbackHour: 16)
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
                Text("피임약 구매 알림 설정")
                    .font(.semibold_18)
                    .foregroundStyle(.textPrimary)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    applyChanges()
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

    private func timeFromSettings(_ components: DateComponents, fallbackHour: Int) -> Date {
        let now = Date()
        let hour = components.hour ?? fallbackHour
        let minute = components.minute ?? 0
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) ?? now
    }

    private func applyChanges() {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        viewModel.updateNotifications {
            $0.pillPurchaseReminderDaysBefore = selectedDaysBefore
            $0.pillPurchaseReminderTime = timeComponents
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
