//
//  DayInfoCardView.swift
//  BloodyDay
//
//  Created by Yunki on 10/13/25.
//

import SwiftUI

struct DayInfoCardView: View {
    let primaryStatus: CalendarPrimaryStatus
    let secondaryStatus: CalendarSecondaryStatus
    
    private var primaryIcon: some View {
        return Image(systemName: "drop.fill")
            .foregroundStyle(.mainRed)
            .font(.system(size: 14, weight: .regular))
    }
    
    @ViewBuilder
    private var secondaryIcon: some View {
        switch secondaryStatus {
        case .pill(_, _), .pillBreak(_, _):
            Image(.pillHalf)
                .foregroundStyle(.subBlue)
                .frame(width: 13, height: 13)
        default:
            Image(systemName: "sparkle")
                .foregroundStyle(.mainNeutral)
                .font(.system(size: 14, weight: .regular))
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 3) {
                    primaryIcon
                        .frame(width: 20, height: 20)
                    
                    Text(primaryStatus.displayText)
                        .font(.regular_16)
                        .foregroundStyle(.textPrimary)
                    
                    if let subText = primaryStatus.subText {
                        Text(subText)
                            .font(.regular_14)
                            .foregroundStyle(.textSecondary40)
                    }
                }
                
                HStack(spacing: 3) {
                    secondaryIcon
                        .frame(width: 20, height: 20)
                    
                    Text(secondaryStatus.displayText)
                        .font(.regular_16)
                        .foregroundStyle(.textPrimary)
                    
                    if let subText = secondaryStatus.subText {
                        Text(subText)
                            .font(.regular_14)
                            .foregroundStyle(.textSecondary40)
                    }
                }
            }
            .foregroundStyle(.textPrimary)
            
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .background {
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.bgSecondary)
        }
        .padding(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
    }
}

#Preview {
    DayInfoCardView(
        primaryStatus: .countdown(days: 14),
        secondaryStatus: .notFertile
    )
}
