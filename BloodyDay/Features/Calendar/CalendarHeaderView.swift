//
//  CalendarHeaderView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarHeaderView: View {
    let month: Date
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(month.component(.year))년")
                    .font(.medium_16)
                
                HStack(spacing: 9) {
                    Text("\(month.component(.month))월")
                        .font(.semibold_32)
                    
                    Image(systemName: "chevron.right")
                        .bold()
                        .foregroundStyle(.icon)
                        .frame(width: 13, height: 16)
                }
            }
            .padding(21)
            
            Spacer()
            
            Menu {
                
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.icon)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .frame(width: 44, height: 44)
            .padding(.trailing, 16)

        }
    }
}

#Preview {
    CalendarHeaderView(month: .now)
}
