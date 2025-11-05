//
//  TestTabBar.swift
//  BloodyDay
//
//  Created by Yunki on 11/5/25.
//

import SwiftUI

struct TestTabBar: View {
    @State var activeTab: BloodyDayTab = .calendar
    var body: some View {
        VStack {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 100) {
                    GeometryReader {
                        BloodyDayTabBar(size: $0.size, activeTab: $activeTab) { tab in
                            VStack(spacing: 3) {
                                Image(systemName: tab.symbol)
                                    .font(.title3)
                                
                                Text(tab.rawValue)
                                    .font(.medium_11)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 55, height: 55)
                    .glassEffect(.regular.interactive(), in: Circle())
                }
            }
            .frame(height: 55)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    TestTabBar()
}
