//
//  BloodyDayRootView.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import SwiftUI

struct BloodyDayRootView: View {
    var body: some View {
        TabView {
            Tab("달력", systemImage: "calendar") {
                CalendarMainView()
            }
            
            Tab("주기", systemImage: "clock") {
                CalendarMainView()
            }
        }
        .tint(.mainRed)
    }
}

#Preview {
    BloodyDayRootView()
}
