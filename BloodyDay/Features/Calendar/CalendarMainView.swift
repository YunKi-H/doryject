//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    let days: [DayInfo] = (0..<42).map { offset in
        DayInfo(date: Calendar.current.date(byAdding: .day, value: offset, to: .now.startOfCalendarGrid())!)
    }
    
    var body: some View {
        VStack {
            CalendarHeaderView()
            
            CalendarView(days: days)
            
            DayInfoCardView()
        }
    }
}

#Preview {
    CalendarMainView()
}
