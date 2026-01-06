//
//  DayInfoCardView.swift
//  BloodyDay
//
//  Created by Yunki on 10/13/25.
//

import SwiftUI

struct DayInfoCardView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.regular_16)
                Text(subtitle)
                    .font(.regular_16)
            }
            .foregroundStyle(.textPrimary)
            
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
    DayInfoCardView(title: "B-14", subtitle: "가임기 아님")
}
