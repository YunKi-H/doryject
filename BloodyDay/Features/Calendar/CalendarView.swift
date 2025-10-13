//
//  CalendarView.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import SwiftUI

struct CalendarView: View {
    let days: [DayInfo]
    
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) {
                    Text($0)
                        .frame(maxWidth: .infinity)
                }
            }
            
            ForEach(0..<6, id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        DayCellView(day: days[index])
                    }
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
