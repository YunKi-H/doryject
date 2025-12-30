//
//  PeriodEditSheetView.swift
//  BloodyDay
//
//  Created by Yunki on 12/14/25.
//

import SwiftUI

struct PeriodEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var months: [MonthInfo] = [
        .init(
            monthDate: .now,
            days: Date.dates(from: .now.startOfCalendarGrid(), to: .now.endOfCalendarGridExclusiveStart()).map({ date in
            DayInfo(date: date)
        }),
            periodRanges: [],
            delayedRanges: [],
            fertileRanges: [],
            ovulationRanges: []
        ),
        .init(
            monthDate: .now.endOfCalendarGridExclusiveStart(),
            days: Date.dates(
                from: .now.endOfCalendarGridExclusiveStart().startOfCalendarGrid(),
                to: .now.endOfCalendarGridExclusiveStart().endOfCalendarGridExclusiveStart()
            ).map({ date in
                DayInfo(date: date)
            }),
            periodRanges: [],
            delayedRanges: [],
            fertileRanges: [],
            ovulationRanges: []
        )
    ]
    @State private var selectionMonth: Date?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarHeaderView(
                    month: .now,
                    onSelectDate: { _ in }
                )
                
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(months) { month in
                            CalendarView(
                                month: month,
                                selectedDate: .now,
                                onSelectDate: { _ in }
                            )
                            .containerRelativeFrame(.vertical)
                            .id(month.monthDate)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $selectionMonth, anchor: .top)
                
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
            .background {
                Color.bgPrimary
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .title) {
                    Text("생리 주기 수정")
                        .font(.semibold_18)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        // TODO: - 변경사항 커밋
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.bgSecondary)
                    }
                    .tint(.mainRed)
                    .buttonStyle(.glassProminent)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    PeriodEditSheetView()
}
