//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    @Bindable var viewModel: CalendarViewModel
    @State private var selectionMonth: Date?
    
    @Binding var isPresentedEventSheet: Bool
    
    @State private var initialPeriod: Bool = false
    @State private var initialPill: Bool = false
    @State private var initialLove: Bool = false
    
    @State private var period: Bool = false
    @State private var pill: Bool = false
    @State private var love: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                month: viewModel.selectedDate,
                onSelectDate: viewModel.selectDate(_:)
            )
            
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.months) { month in
                        CalendarView(
                            month: month,
                            selectedDate: viewModel.selectedDate,
                            onSelectDate: viewModel.selectDate(_:)
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
            .onAppear {
                if viewModel.months.indices.contains(viewModel.currentIndex) {
                    selectionMonth = viewModel.months[viewModel.currentIndex].monthDate
                }
            }
            .onChange(of: viewModel.selectedDate, { oldValue, newValue in
                if !oldValue.isInSameMonth(as: newValue) {
                    DispatchQueue.main.async {
                        withAnimation {
                            selectionMonth = newValue.startOfMonth
                        }
                    }
                }
            })
            .onScrollPhaseChange { _, newPhase in
                switch newPhase {
                case .idle:
                    // 스크롤이 완전히 멈춘 시점에서만 동기화
                    guard let month = selectionMonth,
                          let index = viewModel.months.firstIndex(where: { $0.monthDate == month }) else { return }
                    
                    // 같은 페이지면 불필요한 업데이트 방지
                    guard index != viewModel.currentIndex ||
                            viewModel.months[index].monthDate.startOfMonth != viewModel.selectedDate.startOfMonth else { return }
                    
                    viewModel.setCurrentMonth(to: viewModel.months[index].monthDate)
                    
                case .animating, .decelerating, .interacting, .tracking:
                    break
                @unknown default:
                    break
                }
            }
            
            DayInfoCardView()
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentedEventSheet) {
            NavigationStack {
                Form {
                    Section(header: EmptyView()) {
                        Toggle(isOn: $period) {
                            Label {
                                Text("생리")
                            } icon: {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.mainRed)
                            }
                        }
                        .tint(.mainRed)
                        
                        Toggle(isOn: $pill) {
                            Label {
                                Text("피임약 복용")
                            } icon: {
                                Image(.pillHalf)
                                    .foregroundStyle(.subBlue)
                            }
                        }
                        .tint(.subBlue)
                        
                        Toggle(isOn: $love) {
                            Label {
                                Text("사랑한 날")
                            } icon: {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.subPink)
                            }
                        }
                        .tint(.subPink)
                    }
                    .listRowBackground(Color.bgSecondary)
                }
                .padding(.top, 14)
                .contentMargins(.top, 0)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isPresentedEventSheet = false
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    ToolbarItem(placement: .title) {
                        let selectedDate = viewModel.selectedDate
                        let month = selectedDate.component(.month)
                        let day = selectedDate.component(.day)
                        let weekDay = Date.FormatStyle()
                            .weekday(.wide)
                            .format(selectedDate)
                        Text("\(month)월 \(day)일 \(weekDay)")
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) {
                            let initial: Set<EventType> = Set([
                                initialPeriod ? .period : nil,
                                initialPill ? .pill : nil,
                                initialLove ? .love : nil
                            ].compactMap{ $0 })
                            
                            let final: Set<EventType> = Set([
                                period ? .period : nil,
                                pill ? .pill : nil,
                                love ? .love : nil
                            ].compactMap { $0 })
                            
                            viewModel.commitEventsForSelectedDate(from: initial, to: final)
                            isPresentedEventSheet = false
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
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.visible)
            .onAppear {
                let hasPeriod = viewModel.isEventOnSelectedDate(.period)
                let hasPill = viewModel.isEventOnSelectedDate(.pill)
                let hasLove = viewModel.isEventOnSelectedDate(.love)
                
                self.period = hasPeriod
                self.pill = hasPill
                self.love = hasLove
                
                self.initialPeriod = hasPeriod
                self.initialPill = hasPill
                self.initialLove = hasLove
            }
        }
    }
}

#Preview {
    CalendarMainView(
        viewModel: .init(eventRepository: MockEventRepository()),
        isPresentedEventSheet: .constant(false)
    )
}
