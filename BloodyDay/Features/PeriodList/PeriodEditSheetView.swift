//
//  PeriodEditSheetView.swift
//  BloodyDay
//
//  Created by Yunki on 12/14/25.
//

import SwiftUI

struct PeriodEditSheetView: View {
    @Bindable var viewModel: PeriodListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var months: [MonthInfo] = []
    @State private var selectionMonth: Date?
    @State private var selectedDate: Date
    @State private var currentIndex: Int = 0
    @State private var selectedPeriodDates: Set<Date> = []
    @State private var originalPeriodDates: Set<Date> = []
    @State private var datePickerPresented: Bool = false
    @State private var newDate: Date = .now
    @State private var discardPopoverPresented: Bool = false
    
    init(viewModel: PeriodListViewModel, initialDate: Date = .now) {
        self.viewModel = viewModel
        self._selectedDate = State(initialValue: initialDate.startOfDay)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(months) { month in
                            CalendarView(
                                month: month,
                                selectedDate: selectedDate,
                                onSelectDate: { date in
                                    togglePeriod(on: date)
                                }
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
                .onChange(of: selectionMonth) { _, newValue in
                    guard let newValue else { return }
                    let monthStart = newValue.startOfMonth
                    if months.indices.contains(currentIndex),
                       months[currentIndex].monthDate == monthStart {
                        return
                    }
                    setCurrentMonth(to: monthStart)
                    selectedDate = monthStart
                }
                
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
            .background {
                Color.bgPrimary
                    .ignoresSafeArea()
            }
            .onAppear {
                selectedPeriodDates = viewModel.periodDates()
                originalPeriodDates = selectedPeriodDates
                bootstrapMonths(anchor: selectedDate.startOfMonth)
                selectionMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : selectedDate.startOfMonth
            }
            .sheet(isPresented: $datePickerPresented) {
                NavigationStack {
                    DatePicker("", selection: $newDate, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.init(top: 18, leading: 12, bottom: 18, trailing: 12))
                        .background(RoundedRectangle(cornerRadius: 20).fill(.bgSecondary))
                        .padding(.init(top: 0, leading: 16, bottom: 42, trailing: 16))
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    datePickerPresented = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            ToolbarItem(placement: .title) {
                                Text("날짜")
                            }
                            
                            ToolbarItem(placement: .confirmationAction) {
                                Button(role: .confirm) {
                                    selectDate(newDate)
                                    datePickerPresented = false
                                } label: {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.bgSecondary)
                                }
                                .tint(.mainRed)
                                .buttonStyle(.glassProminent)
                            }
                }
            }
            .appGradientOverlay()
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hasChanges {
                            discardPopoverPresented = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .popover(isPresented: $discardPopoverPresented) {
                        VStack(spacing: 10) {
                            Text("변경한 생리 주기를 저장하지\n않고 취소하시겠습니까?")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(EdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8))
                                .padding(EdgeInsets(top: 14, leading: 14, bottom: 0, trailing: 14))
                            
                            Button("취소하기") {
                                dismiss()
                            }
                            .font(.medium_18)
                            .frame(height: 48)
                            .frame(maxWidth: .infinity)
                            .background{
                                RoundedRectangle(cornerRadius: 100)
                                    .fill(Color(UIColor.secondarySystemFill))
                            }
                            .tint(.mainRed)
                            .padding(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                }
                
                ToolbarItem(placement: .title) {
                    Text("생리 주기 수정")
                        .font(.semibold_18)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        viewModel.applyPeriodDates(selectedPeriodDates)
                        dismiss()
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
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(selectedDate.component(.year).formatted(.number.grouping(.never)))년")
                        .font(.medium_16)
                        .padding(.leading, 1)
                    
                    HStack(spacing: 9) {
                        Text("\(selectedDate.component(.month))월")
                            .font(.semibold_32)
                        
                        Image(systemName: "chevron.right")
                            .bold()
                            .foregroundStyle(.icon)
                            .frame(width: 13, height: 16)
                            .rotationEffect(datePickerPresented ? .degrees(90) : .degrees(0))
                            .animation(.default, value: datePickerPresented)
                    }
                }
                .padding(21)
                .foregroundStyle(.textPrimary)
                .onTapGesture {
                    newDate = selectedDate
                    datePickerPresented = true
                }
                
                Spacer()
                
                Button {
                    selectDate(.now)
                } label: {
                    Text("오늘")
                        .font(.medium_16)
                        .padding(.init(top: 10, leading: 20, bottom: 10, trailing: 20))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .frame(height: 44)
                .padding(.trailing, 16)
            }
            
            HStack(spacing: 0) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) {
                    Text($0)
                        .font(.medium_11)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 5)
            
            Rectangle()
                .fill(.mainNeutralSecondary.opacity(0.12))
                .frame(height: 1)
        }
    }
    
    private func selectDate(_ date: Date) {
        if !selectedDate.isInSameMonth(as: date) {
            setCurrentMonth(to: date)
        }
        selectedDate = date
        withAnimation {
            selectionMonth = date.startOfMonth
        }
    }
    
    private func togglePeriod(on date: Date) {
        selectDate(date)
        let normalized = date.startOfDay
        if selectedPeriodDates.contains(normalized) {
            selectedPeriodDates.remove(normalized)
        } else {
            selectedPeriodDates.insert(normalized)
        }
        refreshMonths()
    }
    
    private func refreshMonths() {
        let monthDates = months.map(\.monthDate)
        months = monthDates.map { makeMonthInfo(for: $0) }
    }
    
    private func setCurrentMonth(to month: Date) {
        let start = month.startOfMonth
        if let idx = months.firstIndex(where: { $0.monthDate == start }) {
            currentIndex = idx
            loadPreviousIfNeeded(viewingIndex: idx)
            loadNextIfNeeded(viewingIndex: idx)
        } else {
            bootstrapMonths(anchor: start)
        }
        selectionMonth = months.indices.contains(currentIndex) ? months[currentIndex].monthDate : start
    }
    
    private func loadPreviousIfNeeded(viewingIndex index: Int) {
        guard index <= 1, let first = months.first?.monthDate else { return }
        let prev = makeMonthInfo(for: first.addingMonths(-1))
        months.insert(prev, at: 0)
        currentIndex += 1
    }
    
    private func loadNextIfNeeded(viewingIndex index: Int) {
        guard index >= months.count - 2, let last = months.last?.monthDate else { return }
        let next = makeMonthInfo(for: last.addingMonths(+1))
        months.append(next)
    }
    
    private func bootstrapMonths(anchor: Date) {
        let prev = makeMonthInfo(for: anchor.addingMonths(-1))
        let current = makeMonthInfo(for: anchor)
        let next = makeMonthInfo(for: anchor.addingMonths(1))
        months = [prev, current, next]
        currentIndex = 1
    }
    
    private func makeMonthInfo(for month: Date) -> MonthInfo {
        let monthStart = month.startOfMonth
        let days = buildDayInfos(for: month)
        let periodRanges: [DateInterval] = buildRangesSplittingByWeeks(days: days) { day in
            day.events.contains { $0.type == .period }
        }
        return MonthInfo(
            monthDate: monthStart,
            days: days,
            periodRanges: periodRanges,
            predictedPeriodRanges: [],
            predictedPeriodDates: [],
            delayedRanges: [],
            fertileRanges: [],
            ovulationRanges: []
        )
    }
    
    private func buildDayInfos(for month: Date) -> [DayInfo] {
        let gridStart = month.startOfCalendarGrid()
        let gridEndExclusive = month.endOfCalendarGridExclusiveStart()
        return Date.dates(from: gridStart, to: gridEndExclusive).map { date in
            if selectedPeriodDates.contains(date.startOfDay) {
                return DayInfo(date: date, events: [DayEvent(type: .period)])
            }
            return DayInfo(date: date)
        }
    }
    
    private func buildRangesSplittingByWeeks(
        days: [DayInfo],
        hasEvent: (DayInfo) -> Bool,
        columns: Int = 7
    ) -> [DateInterval] {
        var ranges: [DateInterval] = []
        var currentStart: Date? = nil
        var lastIndex: Int? = nil
        
        for idx in days.indices {
            let day = days[idx]
            let isOn = hasEvent(day)
            
            if isOn {
                if currentStart == nil {
                    currentStart = day.date
                    lastIndex = idx
                } else {
                    if let li = lastIndex, li % columns == columns - 1 {
                        let endDate = days[li].date
                        ranges.append(DateInterval(start: currentStart!, end: endDate))
                        currentStart = day.date
                    }
                    lastIndex = idx
                }
            } else if let li = lastIndex, let start = currentStart {
                let endDate = days[li].date
                ranges.append(DateInterval(start: start, end: endDate))
                currentStart = nil
                lastIndex = nil
            }
        }
        
        if let li = lastIndex, let start = currentStart {
            let endDate = days[li].date
            ranges.append(DateInterval(start: start, end: endDate))
        }
        
        return ranges
    }
    
    private var hasChanges: Bool {
        selectedPeriodDates != originalPeriodDates
    }
}

#Preview {
    PeriodEditSheetView(viewModel: .init(eventRepository: MockEventRepository()))
}
