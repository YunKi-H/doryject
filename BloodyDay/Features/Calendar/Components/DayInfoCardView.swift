//
//  DayInfoCardView.swift
//  BloodyDay
//
//  Created by Yunki on 10/13/25.
//

import SwiftUI

struct DayInfoCardView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("B-Day 지연")
                    .font(.system(size: 16))
                Text("임신 확률 낮음")
                    .font(.system(size: 16))
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    DayInfoCardView()
}
