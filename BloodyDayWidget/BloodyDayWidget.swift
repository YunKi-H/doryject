//
//  BloodyDayWidget.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            snapshot: .placeholder
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: configuration,
            snapshot: WidgetSnapshotStore().load() ?? .placeholder
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let entry = SimpleEntry(
            date: currentDate,
            configuration: configuration,
            snapshot: WidgetSnapshotStore().load() ?? .placeholder
        )
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let snapshot: WidgetSnapshot
}

struct BloodyDayWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.snapshot.chips.isEmpty == false {
                chipRow(entry.snapshot.chips)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.snapshot.primaryText)
                    .font(.semibold_32)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Group {
                    if let primarySubText = entry.snapshot.primarySubText {
                        Text(primarySubText)
                    } else {
                        Color.clear
                    }
                }
                .font(.regular_11)
                .foregroundStyle(.textSecondary50)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 13, alignment: .leading)
            }
            .padding(.leading, 4)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 10) {
                toggleButton(isOn: entry.snapshot.toggles.period, eventType: .period)
                toggleButton(isOn: entry.snapshot.toggles.pill, eventType: .pill)
                toggleButton(isOn: entry.snapshot.toggles.love, eventType: .love)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func chipRow(_ chips: [WidgetChipSnapshot]) -> some View {
        HStack(spacing: 6) {
            ForEach(chips.prefix(3)) { chip in
                chipView(chip)
            }
        }
    }
    
    private func chipView(_ chip: WidgetChipSnapshot) -> some View {
        HStack(spacing: 4) {
            chipIcon(chip)
            Text(chip.text)
                .font(.medium_11)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(chipTextColor(chip))
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(chipBackgroundColor(chip), in: Capsule())
    }
    
    private func toggleButton(isOn: Bool, eventType: ToggleTodayEventKind) -> some View {
        Button(intent: ToggleTodayEventIntent(eventType: eventType)) {
            ZStack {
                Circle()
                    .fill(toggleBackground(for: eventType, isOn: isOn))
                    .frame(width: 36, height: 36)
                toggleIcon(for: eventType, isOn: isOn)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func toggleIcon(for eventType: ToggleTodayEventKind, isOn: Bool) -> some View {
        switch eventType {
        case .period:
            Image(systemName: "drop.fill")
                .frame(width: 22, height: 22)
                .foregroundStyle(isOn ? .textPoint : .textSecondary20)
        case .pill:
            Image(.pillHalf)
                .resizable()
                .frame(width: 17, height: 17)
                .foregroundStyle(isOn ? .textPoint : .textSecondary20)
        case .love:
            Image(systemName: "heart.fill")
                .frame(width: 22, height: 22)
                .foregroundStyle(isOn ? .textPoint : .textSecondary20)
        }
    }
    
    private func toggleBackground(for eventType: ToggleTodayEventKind, isOn: Bool) -> LinearGradient {
        let baseColor = toggleBaseColor(for: eventType, isOn: isOn)
        
        return LinearGradient(
            colors: [
                baseColor.opacity(isOn ? 1.0 : 0.12),
                baseColor.opacity(isOn ? 0.74 : 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func toggleBaseColor(for eventType: ToggleTodayEventKind, isOn: Bool) -> Color {
        let baseColor: Color
        if isOn {
            switch eventType {
            case .period:
                baseColor = .mainRed
            case .pill:
                baseColor = .subBlue
            case .love:
                baseColor = .subPink
            }
        } else {
            baseColor = .textPrimary
        }
        return baseColor
    }
    
    private func chipTextColor(_ chip: WidgetChipSnapshot) -> Color {
        switch chip.kind {
        case .period:
            return .pointRed
        case .pill:
            return .pointBlue
        case .fertility:
            return .textPrimary
        }
    }
    
    private func chipBackgroundColor(_ chip: WidgetChipSnapshot) -> Color {
        switch chip.kind {
        case .period:
            return .mainRed10
        case .pill:
            return .subBlue10
        case .fertility:
            return .textTertiary8
        }
    }
    
    @ViewBuilder
    private func chipIcon(_ chip: WidgetChipSnapshot) -> some View {
        switch chip.kind {
        case .period:
            Image(systemName: "drop.fill")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(chipTextColor(chip))
        case .pill:
            Image(.pillHalf)
                .resizable()
                .foregroundStyle(chipTextColor(chip))
                .frame(width: 10, height: 10)
        case .fertility:
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(chipTextColor(chip))
        }
    }
    
}

struct BloodyDayWidget: Widget {
    let kind: String = "BloodyDayWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BloodyDayWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("오늘 요약")
        .description("오늘의 생리 상태와 이벤트 요약을 표시합니다.")
    }
}

struct BloodyDayLockScreenCircularWidget: Widget {
    let kind: String = "BloodyDayLockScreenCircularWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VStack(spacing: 2) {
                Text(entry.snapshot.primaryText)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                if let firstChip = entry.snapshot.chips.first {
                    Text(firstChip.text)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(lockScreenChipTextColor(firstChip))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
        .supportedFamilies([.accessoryCircular])
        .configurationDisplayName("생리 요약")
    }
}

struct BloodyDayLockScreenRectangularWidget: Widget {
    let kind: String = "BloodyDayLockScreenRectangularWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.snapshot.primaryText)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Group {
                    if let primarySubText = entry.snapshot.primarySubText {
                        Text(primarySubText)
                    } else {
                        Color.clear
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 12, alignment: .leading)
                if let firstChip = entry.snapshot.chips.first {
                    Text(firstChip.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(lockScreenChipTextColor(firstChip))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
        .supportedFamilies([.accessoryRectangular])
        .configurationDisplayName("상태 문구")
    }
}

private func lockScreenChipTextColor(_ chip: WidgetChipSnapshot) -> Color {
    switch chip.kind {
    case .period:
        return .pointRed
    case .pill:
        return .pointBlue
    case .fertility:
        return .textPrimary
    }
}

private extension WidgetSnapshot {
    static let placeholder = WidgetSnapshot(
        generatedAt: .now,
        primaryText: "B-3",
        primarySubText: nil,
        chips: [
            .init(id: "pill", kind: .pill, text: "(18/21)"),
            .init(id: "fertility", kind: .fertility, text: "매우높음"),
            .init(id: "period", kind: .period, text: "진행")
        ],
        toggles: .init(period: false, pill: true, love: true)
    )
}

#Preview(as: .systemSmall) {
    BloodyDayWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .init(), snapshot: .placeholder)
}
