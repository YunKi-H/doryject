//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    @State private var viewModel: CalendarViewModel = .init()
    
    var body: some View {
        VStack {
            CalendarHeaderView()
            
            CalendarView(days: viewModel.days)
            
            DayInfoCardView()
        }
    }
}

#Preview {
    CalendarMainView()
}
