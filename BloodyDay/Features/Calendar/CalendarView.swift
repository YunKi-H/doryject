//
//  CalendarView.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import SwiftUI

struct CalendarView: View {
    let month: MonthInfo
    let selectedDate: Date
    let onSelectDate: (Date) -> Void
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geo in
                    PeriodCapsuleLayer(ranges: month.periodRanges, days: month.days, geo: geo)
                    PredictedCapsuleLayer(ranges: month.predictedRanges, days: month.days, geo: geo)
                    FertileCapsuleLayer(ranges: month.fertileRanges, days: month.days, geo: geo)
                    OvulationCapsuleLayer(ranges: month.ovulationRanges, days: month.days, geo: geo)
                    
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(0..<6, id: \.self) { row in
                            GridRow {
                                ForEach(0..<7, id: \.self) { col in
                                    let index = row * 7 + col
                                    let day = month.days[index]
                                    DayCellView(
                                        day: day,
                                        isSelected: selectedDate.isSameDay(as: day.date),
                                        monthDate: month.monthDate
                                    ) { date in
//                                        selectedDate = date
                                        onSelectDate(date)
                                    }
                                }
                            }
                        }
                    }
                    .overlay {
                        ForEach(0...rows, id: \.self) { r in
                            let cellHeight = geo.size.height / CGFloat(rows)
                            let y = CGFloat(r) * cellHeight
                            
                            Rectangle()
                                .fill(.mainNeutral8)
                                .frame(height: 1)
                                .position(x: geo.size.width / 2, y: y) // 경계선
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
        month: .init(
            monthDate: .now,
            days: days,
            periodRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 3, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 5, to: baseDate)!)],
            predictedRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 9, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 12, to: baseDate)!)],
            fertileRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 14, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 19, to: baseDate)!)],
            ovulationRanges: [DateInterval(start: Calendar.current.date(byAdding: .day, value: 15, to: baseDate)!, end: Calendar.current.date(byAdding: .day, value: 18, to: baseDate)!)]
        ),
        selectedDate: .now,
        onSelectDate: { _ in }
    )
}
