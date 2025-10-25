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
        VStack {
            CalendarHeaderView(month: viewModel.selectedDate)
            
            CalendarView(
                days: viewModel.days,
                periodRanges: viewModel.periodRanges,
                predictedRanges: viewModel.predictedRanges,
                fertileRanges: viewModel.fertileRanges,
                ovulationRanges: viewModel.ovulationRanges
            )
            
            DayInfoCardView()
        }
    }
}

#Preview {
    CalendarMainView()
}
