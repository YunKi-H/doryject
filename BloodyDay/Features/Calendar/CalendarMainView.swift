//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    @State private var viewModel: CalendarViewModel = .init(eventRepository: MockEventRepository(), cycleAnalyzer: .init(), cyclePredictor: .init())
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(month: viewModel.selectedDate)
            
            CalendarView(month: viewModel.months[viewModel.currentIndex])
            
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
