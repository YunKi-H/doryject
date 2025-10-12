//
//  CalendarView.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import SwiftUI

struct CalendarView: View {
    let days: [DayInfo]
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) {
                    Text($0)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(days) { day in
                    DayCellView(day: day)
                }
            }
        }
    }
}

#Preview {
    let date = Date.now.startOfCalendarGrid()
    CalendarView(days: (0..<42).map { offset in
        DayInfo(date: Calendar.current.date(byAdding: .day, value: offset, to: date)!)
    })
}
