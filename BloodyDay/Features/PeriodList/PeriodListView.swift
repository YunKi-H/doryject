//
//  PeriodListView.swift
//  BloodyDay
//
//  Created by Yunki on 12/13/25.
//

import SwiftUI

struct PeriodListView: View {
    @State private var editSheetIsPresented: Bool = false
    @State private var settingSheetIsPresented: Bool = false
    @State private var viewModel: PeriodListViewModel
    
    init(viewModel: PeriodListViewModel) {
        _viewModel = State(initialValue: viewModel)
        print("periodListView")
    }
    
    var body: some View {
        let summaries = viewModel.summaries.reversed()
        VStack(alignment: .trailing, spacing: 20) {
            HStack(spacing: 0) {
                Button {
                    editSheetIsPresented = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .padding(6)
                
                Button {
                    settingSheetIsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .padding(6)
            }
            .foregroundStyle(.icon)
            .glassEffect()
            .padding(.horizontal, 16)
            
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("마지막 생리일")
                                .font(.regular_18)
                            Spacer()
                            Text(viewModel.lastPeriodStartDisplay)
                                .font(.semibold_18)
                        }
                        .foregroundStyle(.textPrimary)
                        
                        Text(viewModel.lastPeriodRangeDisplay)
                            .font(.regular_14)
                            .foregroundStyle(.textSecondary40)
                    }
                }
                .listRowBackground(Color.bgSecondary)
                
                Section {
                    HStack {
                        Text("평균 기간")
                            .font(.regular_18)
                        Spacer()
                        Text(viewModel.averagePeriodDisplay)
                            .font(.semibold_18)
                    }
                    .foregroundStyle(.textPrimary)
                    
                    HStack {
                        Text("평균 주기")
                            .font(.regular_18)
                        Spacer()
                        Text(viewModel.averageCycleDisplay)
                            .font(.semibold_18)
                    }
                    .foregroundStyle(.textPrimary)
                }
                .listRowBackground(Color.bgSecondary)
                
                Section {
                    ForEach(summaries) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(viewModel.format(summary.start)) - \(viewModel.format(summary.end))")
                                .font(.semibold_18)
                                .foregroundStyle(.textPrimary)
                                .padding(.leading, 5)
                            
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("생리 기간")
                                        .font(.medium_14)
                                        .foregroundStyle(.textSecondary40)
                                    Text("\(summary.lengthDays)일")
                                        .font(.semibold_14)
                                        .foregroundStyle(.textSecondary50)
                                }
                                .padding(.init(top: 4.5, leading: 8, bottom: 4.5, trailing: 8))
                                .background {
                                    RoundedRectangle(cornerRadius: 26)
                                        .fill(Color.component)
                                }
                                
                                HStack(spacing: 4) {
                                    Text("생리 주기")
                                        .font(.medium_14)
                                        .foregroundStyle(.textSecondary40)
                                    Text(summary.cycleDays.map { "\($0)일" } ?? "-")
                                        .font(.semibold_14)
                                        .foregroundStyle(.textSecondary50)
                                }
                                .padding(.init(top: 4.5, leading: 8, bottom: 4.5, trailing: 8))
                                .background {
                                    RoundedRectangle(cornerRadius: 26)
                                        .fill(Color.component)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                // delete
                            } label: {
                                VStack {
                                    Image(systemName: "trash")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.textPoint)
                                        .tint(.mainRed)
                                    Text("삭제")
                                        .foregroundStyle(.textSecondary50)
                                }
                            }
                            
                            Button {
                                // edit
                            } label: {
                                VStack {
                                    Image(systemName: "pencil")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.textPoint)
                                        .tint(.mainNeutral)
                                    Text("수정")
                                        .foregroundStyle(.textSecondary50)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.bgSecondary)
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 14)
            .scrollContentBackground(.hidden)
            
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $editSheetIsPresented) {
            PeriodEditSheetView()
        }
        .sheet(isPresented: $settingSheetIsPresented) {
            PeriodSettingSheetView()
        }
    }
}

#Preview {
    NavigationStack {
        PeriodListView(viewModel: .init(eventRepository: MockEventRepository()))
    }
}
