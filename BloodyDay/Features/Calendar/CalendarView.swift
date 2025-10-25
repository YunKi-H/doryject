//
//  CalendarView.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import SwiftUI

struct CalendarView: View {
    let days: [DayInfo]
    let periodRanges: [DateInterval]
    let predictedRanges: [DateInterval]
    let fertileRanges: [DateInterval]
    let ovulationRanges: [DateInterval]
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) {
                    Text($0)
                        .font(.medium_11)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            ZStack {
                GeometryReader { geo in
                    PeriodCapsuleLayer(ranges: periodRanges, days: days, geo: geo)
                    PredictedCapsuleLayer(ranges: predictedRanges, days: days, geo: geo)
                    FertileCapsuleLayer(ranges: fertileRanges, days: days, geo: geo)
                    OvulationCapsuleLayer(ranges: ovulationRanges, days: days, geo: geo)
                    
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
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
        }
    }
}

#Preview {
    let baseDate = Date().startOfCalendarGrid()
    let days = (0..<42).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: offset, to: baseDate)!
        let event: [DayEvent] = offset == 10 ? [.init(type: .pill(3)), .init(type: .love)] : []
        return DayInfo(date: date, events: event)
    }
    
    CalendarView(
        days: days,
        periodRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 5, to: baseDate)!)],
        predictedRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 9, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 12, to: baseDate)!)],
        fertileRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 14, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 19, to: baseDate)!)],
        ovulationRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 15, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 18, to: baseDate)!)]
    )
}
