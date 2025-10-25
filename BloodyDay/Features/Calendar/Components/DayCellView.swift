//
//  DayCellView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct DayCellView: View {
    let day: DayInfo
    
    var pill: DayEvent? { day.events.first(where: { if case .pill(_) = $0.type { return true } else { return false } }) }
    var love: DayEvent? { day.events.first(where: { $0.type == .love }) }
    
    var body: some View {
        VStack {
            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.medium_16)
                .foregroundStyle(.textPrimary)
                .padding(.top, 12)
            
            Spacer()
            
            HStack(spacing: 0) {
                if love != nil {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.subPink40)
                        .font(.system(size: 11))
                }
                
                if case let .pill(count) = pill?.type {
                    HStack(spacing: 4) {
                        Image(.pillHalf)
                            .resizable()
                            .foregroundStyle(.subBlue30)
                            .frame(width: 10, height: 10)
                        
                        Text("\(count)")
                            .font(.regular_11)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .padding(.init(top: 0, leading: 6, bottom: 10, trailing: 6))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DayCellView(day: .init(
        date: .now,
        events: [
            .init(type: .love),
            .init(type: .pill(3))
        ]
    ))
}
