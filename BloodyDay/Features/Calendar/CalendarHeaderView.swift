//
//  CalendarHeaderView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("2025년")
            
            HStack(spacing: 6) {
                Text("9월")
                
                ZStack {
                    Circle()
                        .frame(width: 30, height: 30)
                        .glassEffect(.clear)
                    
                    Image(systemName: "chevron.right")
                        .bold()
                }
            }
        }
        .padding(21)
    }
}

#Preview {
    CalendarHeaderView()
}
