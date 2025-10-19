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
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.system(size: 16))
                .padding(.vertical, 4)
            
            Spacer()
            
            HStack(spacing: 0) {
                if love != nil {
                    Image(systemName: "heart.fill")
                }
                
                if case let .pill(count) = pill?.type {
                    HStack(spacing: 4) {
                        Image(systemName: "pill.fill")
                        
                        Text("\(count)")
                            .font(.system(size: 11))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DayCellView(day: .init(
        date: .now,
        events: [
            .init(type: .love, isStart: false, isEnd: false),
            .init(type: .pill(4), isStart: false, isEnd: false)
        ]
    ))
}
