//
//  DayCellView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct DayCellView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let day: DayInfo
    let isSelected: Bool
    let isPredictedPeriodDay: Bool
    let monthDate: Date
    var onTap: (Date) -> Void
    
    private var isToday: Bool { day.date.isSameDay(as: .now) }
    private var pill: DayEvent? { day.events.first(where: { $0.type == .pill }) }
    private var love: DayEvent? { day.events.first(where: { $0.type == .love }) }
    private var isInCurrentMonth: Bool { day.date.isInSameMonth(as: monthDate) }
    private var dateFontColor: Color {
        if isToday { return .bgSecondary }
        if isSelected && day.events.contains(where: { $0.type == .period }) { return .textPrimary }
        if isPredictedPeriodDay {
            return .textPrimary
        }
        if day.events.contains(where: { $0.type == .period }) {
            return .textPoint
        }
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
                                .frame(width: 38, height: 20)
                                .glassEffect(.clear.tint(isToday ? .textPrimary : .bgSecondary))
                                .opacity(isInCurrentMonth ? 1 : 0.3)
                        } else {
                            Circle()
                                .frame(width: 30, height: 30)
                                .glassEffect(.clear.tint(isToday ? .textPrimary : .bgSecondary), in: .circle)
                                .shadow(color: .textTertiary8, radius: 2)
                                .opacity(isInCurrentMonth ? 1 : 0.3)
                        }
                    }
                }
                .opacity(isInCurrentMonth ? 1 : 0.3)
                .padding(.top, 12)
            
            Spacer()
            
            HStack(spacing: 0) {
                if love != nil {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.subPink40)
                        .font(.system(size: 11))
                }
                
                if pill != nil, let count = day.pillSequence {
                    HStack(spacing: 4) {
                        Image(.pillHalf)
                            .resizable()
                            .foregroundStyle(colorScheme == .dark ? .subBlue : .subBlue30)
                            .frame(width: 10, height: 10)
                        
                        Text("\(count)")
                            .font(.regular_11)
                            .foregroundStyle(.textTertiary)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.init(top: 0, leading: 6, bottom: 10, trailing: 6))
            .opacity(isInCurrentMonth ? 1 : 0.3)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
        isPredictedPeriodDay: false,
        monthDate: .now
    ) { _ in }
}
