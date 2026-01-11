//
//  PeriodSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/14/25.
//

import SwiftUI

struct PeriodSettingView: View {
    @Bindable var viewModel: PeriodSettingViewModel
    
    @State private var autoCalculate: Bool = true
    
    @State private var togglePeriodPicker: Bool = false
    @State private var averagePeriod: Int = 5
    
    @State private var toggleGapPicker: Bool = false
    @State private var averageGap: Int = 28
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $autoCalculate) {
                        Text("자동 계산")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.mainRed)
                
                if !autoCalculate {
                    Section {
                        Button {
                            withAnimation {
                                toggleGapPicker = false
                                togglePeriodPicker.toggle()
                            }
                        } label: {
                            HStack(spacing: 1) {
                                Text("평균 기간")
                                Spacer()
                                Group {
                                    Text("\(averagePeriod)")
                                    Text("일")
                                }
                                .foregroundStyle(.mainRed)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if togglePeriodPicker {
                            Picker("", selection: $averagePeriod) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)일")
                                        .tag(day)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 140)
                        }
                        
                        Button {
                            withAnimation {
                                togglePeriodPicker = false
                                toggleGapPicker.toggle()
                            }
                        } label: {
                            HStack(spacing: 1) {
                                Text("평균 주기")
                                Spacer()
                                Group {
                                    Text("\(averageGap)")
                                    Text("일")
                                }
                                .foregroundStyle(.mainRed)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if toggleGapPicker {
                            Picker("", selection: $averageGap) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)일")
                                        .tag(day)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 140)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.mainRed)
                }
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 14)
            .scrollContentBackground(.hidden)
            .background {
                Color.bgPrimary
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("생리 주기 설정")
                        .font(.semibold_18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            let period = viewModel.settings.period
            autoCalculate = period.autoCyclePredictionEnabled
            averagePeriod = period.averagePeriodDays ?? 5
            averageGap = period.averageCycleDays ?? 28
        }
        .onChange(of: autoCalculate) { _, newValue in
            viewModel.setAutoPrediction(newValue)
            if newValue {
                viewModel.updateAverages(cycle: nil, period: nil)
            } else {
                viewModel.updateAverages(cycle: averageGap, period: averagePeriod)
            }
        }
        .onChange(of: averagePeriod) { _, newValue in
            guard !autoCalculate else { return }
            viewModel.updateAverages(cycle: averageGap, period: newValue)
        }
        .onChange(of: averageGap) { _, newValue in
            guard !autoCalculate else { return }
            viewModel.updateAverages(cycle: newValue, period: averagePeriod)
        }
    }
}

#Preview {
    PeriodSettingView(viewModel: .init(repo: UserDefaultsSettingsRepository()))
}
