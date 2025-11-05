//
//  BloodyDayRootView.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import SwiftUI

struct BloodyDayRootView: View {
    @State private var activeTab: BloodyDayTab = .calendar
    
    var body: some View {
        TabView(selection: $activeTab) {
            Tab.init(value: .calendar) {
                CalendarMainView()
                    .toolbarVisibility(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 55)
            }
            
            Tab.init(value: .period) {
                CalendarMainView()
                    .toolbarVisibility(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 55)
            }
        }
        
        .safeAreaInset(edge: .bottom) {
            BloodyDayTabBarView()
                .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    func BloodyDayTabBarView() -> some View {
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
}

#Preview {
    BloodyDayRootView()
}
