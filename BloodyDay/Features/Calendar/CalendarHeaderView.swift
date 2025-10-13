//
//  CalendarHeaderView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarHeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("2025년")
                    .font(.system(size: 16))
                
                HStack(spacing: 6) {
                    Text("9월")
                        .font(.system(size: 32))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .bold()
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: .circle)
                }
            }
            .padding(21)
            
            Spacer()
        }
    }
}

#Preview {
    CalendarHeaderView()
}
