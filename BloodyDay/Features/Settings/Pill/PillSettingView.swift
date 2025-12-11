//
//  PillSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/12/25.
//

import SwiftUI

struct PillSettingView: View {
    @State private var pillTaking: Bool = false
    
    @State private var calendarCalculation: Bool = false
    @State private var autoRecord: Bool = false
    
    @State private var pillcount: String = "21"
    @State private var pillBreakDuration: String = "7"
    
    var body: some View {
        VStack {
            List {
                Section {
                    Toggle(isOn: $pillTaking) {
                        Text("경구 피임약 복용")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                }
                .listRowBackground(Color.bgSecondary)
                .tint(.subBlue)
                
                if pillTaking {
                    Section {
                        Toggle(isOn: $calendarCalculation) {
                            Text("피임약 기반 캘린더 계산")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                        }
                        
                        Toggle(isOn: $autoRecord) {
                            Text("캘린더에 복용일 자동 기록")
                                .font(.regular_18)
                                .foregroundStyle(.textPrimary)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subBlue)
                    
                    Section {
                        HStack(spacing: 1) {
                            Text("피임약 개수")
                            
                            Group {
                                TextField("", text: $pillcount)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                Text("정")
                            }
                            .foregroundStyle(.subBlue)
                        }
                        
                        HStack(spacing: 1) {
                            Text("휴약 기간")
                            
                            Group {
                                TextField("", text: $pillBreakDuration)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                Text("일")
                            }
                            .foregroundStyle(.subBlue)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subBlue)
                }
            }
            .listSectionSpacing(14)
            .contentMargins(.top, 14)
            .scrollContentBackground(.hidden)
        }
        .background {
            Color.bgPrimary
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("피임약")
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PillSettingView()
    }
}
