//
//  AppleCalendarSettingView.swift
//  BloodyDay
//
//  Created by Yunki on 12/12/25.
//

import SwiftUI

struct AppleCalendarSettingView: View {
    @State private var appleCalendarLinked: Bool = false
    @State private var savedLocation: String = "B-Day"
    
    @State private var periodDataLinked: Bool = false
    @State private var periodTitle: String = ""
    
    @State private var pillDataLinked: Bool = false
    @State private var pillTitle: String = ""
    
    @State private var loveDataLinked: Bool = false
    @State private var loveTitle: String = ""
    
    var body: some View {
        VStack {
            List {
                Section {
                    Toggle(isOn: $appleCalendarLinked) {
                        Text("Apple Calendar 연결")
                            .font(.regular_18)
                            .foregroundStyle(.textPrimary)
                    }
                    .tint(.mainRed)
                    
                    if appleCalendarLinked {
                        Picker("저장 위치", selection: $savedLocation) {
                            Text("B-Day").tag("B-Day")
                        }
                    }
                }
                .listRowBackground(Color.bgSecondary)
                
                if appleCalendarLinked {
                    Section {
                        Toggle(isOn: $periodDataLinked) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.mainRed)
                                Text("생리 기록 연결")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        if periodDataLinked {
                            TextField(
                                "",
                                text: $periodTitle,
                                prompt: Text("🩸B-Day")
                                    .font(.regular_18)
                                    .foregroundColor(.textPrimary)
                            )
                            .opacity(periodTitle.isEmpty ? 0.15 : 1)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.mainRed)
                    
                    Section {
                        Toggle(isOn: $pillDataLinked) {
                            HStack {
                                Image(.pillHalf)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.subBlue)
                                Text("피임약 기록 연결")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        if pillDataLinked {
                            TextField(
                                "",
                                text: $pillTitle,
                                prompt: Text("💊피임약 복용")
                                    .font(.regular_18)
                                    .foregroundColor(.textPrimary)
                            )
                            .opacity(pillTitle.isEmpty ? 0.15 : 1)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subBlue)
                    
                    Section {
                        Toggle(isOn: $loveDataLinked) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.subPink)
                                Text("사랑한 날 기록 연결")
                                    .font(.regular_18)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        
                        if loveDataLinked {
                            TextField(
                                "",
                                text: $loveTitle,
                                prompt: Text("💗사랑한 날")
                                    .font(.regular_18)
                                    .foregroundColor(.textPrimary)
                            )
                            .opacity(loveTitle.isEmpty ? 0.15 : 1)
                        }
                    }
                    .listRowBackground(Color.bgSecondary)
                    .tint(.subPink)
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
                Text("Apple Calendar")
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
        AppleCalendarSettingView()
    }
}
