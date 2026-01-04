//
//  BloodyDayRootView.swift
//  BloodyDay
//
//  Created by Yunki on 10/31/25.
//

import SwiftUI

struct BloodyDayRootView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var calendarViewModel: CalendarViewModel?
    @State private var periodListViewModel: PeriodListViewModel?
    
    @State private var activeTab: BloodyDayTab = .calendar
    @State private var isPresentedCalendarSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            TabView(selection: $activeTab) {
                Tab.init(value: .calendar) {
                    if let viewModel = calendarViewModel {
                        CalendarMainView(
                            viewModel: viewModel,
                            isPresentedEventSheet: $isPresentedCalendarSheet
                        )
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .safeAreaBar(edge: .bottom, spacing: 0) {
                            Text(".")
                                .blendMode(.destinationOver)
                                .frame(height: 62)
                                .opacity(0)
                        }
                    }
                }
                
                Tab.init(value: .period) {
                    if let viewModel = periodListViewModel {
                        PeriodListView(viewModel: viewModel)
                            .toolbarVisibility(.hidden, for: .tabBar)
                            .safeAreaBar(edge: .bottom, spacing: 0) {
                                Text(".")
                                    .blendMode(.destinationOver)
                                    .frame(height: 62)
                                    .opacity(0)
                            }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                BloodyDayTabBarView()
                    .padding(.horizontal, 20)
            }
            .onAppear {
                let eventRepository = SwiftDataEventRepository(context: modelContext)
                if calendarViewModel == nil {
                    calendarViewModel = CalendarViewModel(eventRepository: eventRepository)
                }
                if periodListViewModel == nil {
                    periodListViewModel = PeriodListViewModel(eventRepository: eventRepository)
                }
            }
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
                
                if activeTab == .calendar {
                    Circle()
                        .fill(.mainRed)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.textPoint)
                        }
                        .frame(width: 62, height: 62)
                        .glassEffect(.clear.interactive())
                        .onTapGesture {
                            isPresentedCalendarSheet = true
                        }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 62, height: 62)
                }
            }
            .frame(height: 62)
        }
    }
}

#Preview {
    BloodyDayRootView()
}
