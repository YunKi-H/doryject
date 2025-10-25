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
            VStack(alignment: .leading, spacing: 0) {
                Text("\(month.component(.year))년")
                    .font(.medium_16)
                
                HStack(spacing: 6) {
                    Text("\(month.component(.month))월")
                        .font(.semibold_32)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: .circle)
                }
            }
            .padding(21)
            
            Spacer()
            
            Menu {
                
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.icon)
                
            }
            .glassEffect(.regular, in: .circle)
            .padding(.trailing, 16)

        }
    }
}

#Preview {
    CalendarHeaderView(month: .now)
}
