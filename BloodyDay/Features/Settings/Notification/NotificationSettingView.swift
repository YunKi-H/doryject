//
//  NotificationSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/11/25.
//

import SwiftUI

struct NotificationSettingView: View {
    var body: some View {
        VStack {
            Text("hi")
        }
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("알림")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingView()
    }
}
