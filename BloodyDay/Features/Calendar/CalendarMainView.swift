//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    @State private var viewModel: CalendarViewModel = .init(
        eventRepository: MockEventRepository(),
        cycleAnalyzer: .init(),
        cyclePredictor: .init()
    )
    @State private var selectionID: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(month: viewModel.selectedDate)
            
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.months) { month in
                        CalendarView(month: month)
                            .containerRelativeFrame(.vertical)
                            .id(month.monthDate)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectionID, anchor: .top)
            .onAppear {
                if viewModel.months.indices.contains(viewModel.currentIndex) {
                    selectionID = viewModel.months[viewModel.currentIndex].id
                }
            }
            .onScrollPhaseChange { _, newPhase in
                switch newPhase {
                case .idle:
                    // 스크롤이 완전히 멈춘 시점에서만 동기화
                    guard let id = selectionID,
                          let index = viewModel.months.firstIndex(where: { $0.id == id }) else { return }
                    
                    // 같은 페이지면 불필요한 업데이트 방지
                    guard index != viewModel.currentIndex ||
                            viewModel.months[index].monthDate.startOfMonth != viewModel.selectedDate.startOfMonth else { return }
                    
                    viewModel.currentIndex = index
                    viewModel.selectedDate = viewModel.months[index].monthDate
                    
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
    }
}

#Preview {
    CalendarMainView()
}
