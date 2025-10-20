//
//  CalendarView.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import SwiftUI

struct CalendarView: View {
    let days: [DayInfo]
    
    private let columns = 7
    private let rows = 6
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) {
                    Text($0)
                        .frame(maxWidth: .infinity)
                }
            }
            
            GeometryReader { geo in
                ZStack {
                    ForEach(periodRanges(), id: \.start.id) { range in
                        let startIndex = days.firstIndex(of: range.start)!
                        let endIndex = days.firstIndex(of: range.end)!
                        let startRow = startIndex / columns
                        let startCol = startIndex % columns
                        let endCol = endIndex % columns
                        
                        let cellWidth = geo.size.width / CGFloat(columns)
                        let cellHeight = geo.size.height / CGFloat(rows)
                        
                        // 좌표 계산
                        let startX = CGFloat(startCol) * cellWidth + 1
                        let endX = CGFloat(endCol) * cellWidth + cellWidth - 1
                        let y = CGFloat(startRow) * cellHeight + 14
                        
                        Capsule()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: endX - startX, height: 16)
                            .position(x: (startX + endX) / 2, y: y)
                    }
                    
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
    
    private func periodRanges() -> [(start: DayInfo, end: DayInfo)] {
        var result: [(DayInfo, DayInfo)] = []
        var currentStart: DayInfo?
        
        for (i, day) in days.enumerated() {
            let isPeriod = day.events.contains { $0.type == .period }
            if isPeriod {
                if currentStart == nil { currentStart = day }
                if i < days.count - 1 { // 마지막 날짜
                    let nextRow = (i + 1) / 7
                    let currentRow = i / 7
                    if nextRow != currentRow {
                        result.append((currentStart!, day))
                        currentStart = nil
                    }
                }
            } else {
                if let start = currentStart {
                    result.append((start, days[i - 1]))
                    currentStart = nil
                }
            }
        }
        return result
    }
}

#Preview {
    let baseDate = Date().startOfCalendarGrid()
    let days = (0..<42).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: offset, to: baseDate)!
        let isPeriod = (10...14).contains(offset)
        return DayInfo(
            date: date,
            events: isPeriod ? [DayEvent(type: .period, isStart: offset == 10, isEnd: offset == 14)] : []
        )
    }
    CalendarView(days: days)
}
