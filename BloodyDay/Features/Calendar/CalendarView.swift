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
    let referenceToday: Date
    let onSelectDate: (Date) -> Void
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geo in
                    Group {
                        PeriodCapsuleLayer(
                            ranges: month.periodRanges,
                            predictedRanges: month.predictedPeriodRanges,
                            days: month.days,
                            geo: geo
                        )
                        DelayedCapsuleLayer(ranges: month.delayedRanges, days: month.days, geo: geo)
                        FertileCapsuleLayer(ranges: month.fertileRanges, days: month.days, geo: geo)
                        OvulationCapsuleLayer(ranges: month.ovulationRanges, days: month.days, geo: geo)
                    }
                    .padding(.horizontal, 20)
                    
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(0..<6, id: \.self) { row in
                            GridRow {
                                ForEach(0..<7, id: \.self) { col in
                                    let index = row * 7 + col
                                    let day = month.days[index]
                                    DayCellView(
                                        day: day,
                                        isSelected: selectedDate.isSameDay(as: day.date),
                                        isPredictedPeriodDay: month.predictedPeriodDates.contains(day.date.startOfDay),
                                        monthDate: month.monthDate,
                                        referenceToday: referenceToday
                                    ) { date in
                                        onSelectDate(date)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 0) {
                        ForEach(0..<rows, id: \.self) { _ in
                            Rectangle()
                                .fill(.textTertiary8)
                                .frame(height: 1)
                            Spacer(minLength: 0)
                        }
                        Rectangle()
                            .fill(.textTertiary8)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

#Preview {
    let calendar = Calendar.autoupdatingCurrent
    let baseDate = Date().startOfCalendarGrid()
    let days = (0..<42).map { offset in
        let date = calendar.date(byAdding: .day, value: offset, to: baseDate)!
        let event: [DayEvent] = offset == 10 ? [.init(type: .pill), .init(type: .love)] : []
        return DayInfo(date: date, events: event)
    }
    
    CalendarView(
        month: .init(
            monthDate: Date(),
            days: days,
            periodRanges: [
                CalendarRangeInfo(
                    range: DateInterval(
                        start: calendar.date(byAdding: .day, value: 3, to: baseDate)!,
                        end: calendar.date(byAdding: .day, value: 5, to: baseDate)!
                    ),
                    opacity: 1
                )
            ],
            predictedPeriodRanges: [],
            predictedPeriodDates: [],
            delayedRanges: [
                CalendarRangeInfo(
                    range: DateInterval(
                        start: calendar.date(byAdding: .day, value: 3, to: baseDate)!,
                        end: calendar.date(byAdding: .day, value: 5, to: baseDate)!
                    ),
                    opacity: 1
                )
            ],
            fertileRanges: [
                CalendarRangeInfo(
                    range: DateInterval(
                        start: calendar.date(byAdding: .day, value: 14, to: baseDate)!,
                        end: calendar.date(byAdding: .day, value: 19, to: baseDate)!
                    ),
                    opacity: 1
                )
            ],
            ovulationRanges: [
                CalendarRangeInfo(
                    range: DateInterval(
                        start: calendar.date(byAdding: .day, value: 15, to: baseDate)!,
                        end: calendar.date(byAdding: .day, value: 18, to: baseDate)!
                    ),
                    opacity: 1
                )
            ]
        ),
        selectedDate: Date(),
        referenceToday: Date(),
        onSelectDate: { _ in }
    )
}
