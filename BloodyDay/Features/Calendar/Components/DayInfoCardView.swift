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
                    .font(.regular_16)
                Text("임신 확률 낮음")
                    .font(.regular_16)
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .background {
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.bgSecondary)
        }
        .padding(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
    }
}

#Preview {
    DayInfoCardView()
}
