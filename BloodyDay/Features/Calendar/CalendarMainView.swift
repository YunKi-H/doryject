//
//  CalendarMainView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarMainView: View {
    var body: some View {
        VStack {
            CalendarHeaderView()
            
            CalendarView(days: [])
        }
    }
}

#Preview {
    CalendarMainView()
}
