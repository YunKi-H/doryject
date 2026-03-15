//
//  DayInfoCardView.swift
//  BloodyDay
//
//  Created by Yunki on 10/13/25.
//

import SwiftUI

struct DayInfoCardView: View {
    let date: Date
    let primaryStatus: CalendarPrimaryStatus
    let secondaryStatus: CalendarSecondaryStatus
    let hasLoveEvent: Bool
    
    private static let dateFormatter: DateFormatter = .periodList
    
    @ViewBuilder
    private var secondaryIcon: some View {
        switch secondaryStatus {
        case .pill(_, _), .pillBreak(_, _):
            Image(.pillHalf)
                .resizable()
                .foregroundStyle(.subBlue)
                .frame(width: 13, height: 13)
        default:
            Image(systemName: "sparkle")
                .foregroundStyle(.textPrimary)
                .font(.system(size: 14, weight: .regular))
        }
    }
    
    private var secondaryTextColor: Color {
        switch secondaryStatus {
        case .pill(_, _), .pillBreak(_, _):
            return .subBlue
        case .ovulation, .fertile, .notFertile:
            return .textPrimary
        case .unknown:
            return .textPrimary
        }
    }
    
    private var secondaryBackgroundColor: Color {
        switch secondaryStatus {
        case .pill(_, _), .pillBreak(_, _):
            return .subBlue10
        case .ovulation, .fertile, .notFertile:
            return .bgPrimary
        case .unknown:
            return .bgPrimary
        }
    }
    
    private var secondarySubTextColor: Color {
        switch secondaryStatus {
        case .pill(_, _), .pillBreak(_, _):
            return .subBlue50
        case .ovulation, .fertile, .notFertile:
            return .textSecondary40
        default:
            return .textSecondary40
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.dateFormatter.string(from: date))
                .font(.regular_14)
                .foregroundStyle(.textTertiary)
                .padding(.leading, 6)
            
            HStack(spacing: 8) {
                if primaryStatus != .unknown {
                    statusChip(
                        icon: AnyView(
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.pointRed)
                        ),
                        text: primaryStatus.displayText,
                        subText: primaryStatus.subText,
                        textColor: .pointRed,
                        subTextColor: .mainRed50,
                        backgroundColor: .mainRed10
                    )
                }
                
                if secondaryStatus != .unknown {
                    statusChip(
                        icon: AnyView(secondaryIcon),
                        text: secondaryStatus.displayText,
                        subText: secondaryStatus.subText,
                        textColor: secondaryTextColor,
                        subTextColor: secondarySubTextColor,
                        backgroundColor: secondaryBackgroundColor
                    )
                }
                
                if hasLoveEvent {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.subPink)
                        .frame(width: 26, height: 26)
                        .background {
                            Circle()
                                .fill(.subPink20)
                        }
                        .frame(width: 26, height: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
        .background {
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.bgSecondary)
        }
        .padding(EdgeInsets(top: 11, leading: 16, bottom: 9, trailing: 16))
    }
    
    private func statusChip(
        icon: AnyView,
        text: String,
        subText: String?,
        textColor: Color,
        subTextColor: Color,
        backgroundColor: Color
    ) -> some View {
        HStack(spacing: 4) {
            icon
            Text(text)
                .font(.regular_16)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(textColor)
            if let subText {
                Text(subText)
                    .font(.regular_14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(subTextColor)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background {
            Capsule(style: .continuous)
                .fill(backgroundColor)
        }
    }
}

#Preview {
    DayInfoCardView(
        date: .now,
        primaryStatus: .countdown(days: 14),
        secondaryStatus: .pill(day: 18, total: 21),
        hasLoveEvent: true
    )
}
