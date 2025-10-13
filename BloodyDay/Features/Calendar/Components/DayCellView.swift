//
//  DayCellView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct DayCellView: View {
    let day: DayInfo
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day.date))")
            
            Spacer()
            
            HStack(spacing: 2) {
                
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DayCellView(day: .init(date: .now))
}
