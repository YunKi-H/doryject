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
    let isPredictedPeriodDay: Bool
    let monthDate: Date
    var onTap: (Date) -> Void
    
    private var isToday: Bool { day.date.isSameDay(as: .now) }
    private var pill: DayEvent? { day.events.first(where: { $0.type == .pill }) }
    private var love: DayEvent? { day.events.first(where: { $0.type == .love }) }
    private var dateFontColor: Color {
        if isToday { return .textPoint }
        if isSelected && day.events.contains(where: { $0.type == .period }) { return .textPrimary }
        if isPredictedPeriodDay {
            return day.date.isInSameMonth(as: monthDate) ? .textPrimary : .textQuaternary
        }
        if day.events.contains(where: { $0.type == .period }) {
            return day.date.isInSameMonth(as: monthDate) ? .textPoint : .textPoint50
        }
        if !day.date.isInSameMonth(as: monthDate) { return .textQuaternary }
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
                                .foregroundStyle(isToday ? .mainNeutral : .bgSecondary)
                                .frame(width: 38, height: 20)
                                .glassEffect(.clear)
                                .opacity(day.date.isInSameMonth(as: monthDate) ? 1 : 0.3)
                        } else {
                            Circle()
                                .foregroundStyle(isToday ? .mainNeutral : .bgSecondary)
                                .frame(width: 30, height: 30)
                                .glassEffect(.clear, in: .circle)
                                .shadow(color: .mainNeutral8, radius: 2)
                                .opacity(day.date.isInSameMonth(as: monthDate) ? 1 : 0.3)
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
                
                if pill != nil, let count = day.pillSequence {
                    HStack(spacing: 4) {
                        Image(.pillHalf)
                            .resizable()
                            .foregroundStyle(.subBlue30)
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
            .opacity(day.date.isInSameMonth(as: monthDate) ? 1 : 0.3)
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
