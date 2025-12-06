//
//  DayCellView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct DayCellView: View {
    let day: DayInfo
    let isSelected: Bool
    let monthDate: Date
    var onTap: (Date) -> Void
    
    private var isToday: Bool { day.date.isSameDay(as: .now) }
    private var pill: DayEvent? { day.events.first(where: { $0.type == .pill }) }
    private var love: DayEvent? { day.events.first(where: { $0.type == .love }) }
    private var dateFontColor: Color {
        if !day.date.isInSameMonth(as: monthDate) { return .textTertiary }
        if isToday || day.events.contains(where: { $0.type == .period }) { return .textPoint }
        return .textPrimary
    }
    
    var body: some View {
        VStack {
            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.medium_16)
                .foregroundStyle(dateFontColor)
                .background {
                    if isToday || isSelected {
                        if day.events.contains(where: { $0.type.isCycleRelated }) {
                            Capsule(style: .continuous)
                                .foregroundStyle(isToday ? .textPrimary : .bgSecondary)
                                .frame(width: 38, height: 20)
                                .glassEffect(.clear)
                        } else {
                            Circle()
                                .foregroundStyle(isToday ? .textPrimary : .bgSecondary)
                                .frame(width: 30, height: 30)
                                .glassEffect(.clear, in: .circle)
                        }
                    }
                }
                .padding(.top, 12)
                
            
            Spacer()
            
            HStack(spacing: 0) {
                if love != nil {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.subPink40)
                        .font(.system(size: 11))
                }
                
                if pill != nil {
                    HStack(spacing: 4) {
                        Image(.pillHalf)
                            .resizable()
                            .foregroundStyle(.subBlue30)
                            .frame(width: 10, height: 10)
                        
                        Text("\(1)")
                            .font(.regular_11)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .padding(.init(top: 0, leading: 6, bottom: 10, trailing: 6))
        }
        .frame(maxWidth: .infinity)
        .onTapGesture { onTap(day.date) }
    }
}

#Preview {
    DayCellView(
        day: .init(
            date: .now,
            events: [
                .init(type: .fertile),
                .init(type: .love),
                .init(type: .pill)
            ]
        ),
        isSelected: true,
        monthDate: .now
    ) { _ in }
}
