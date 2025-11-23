//
//  CalendarHeaderView.swift
//  BloodyDay
//
//  Created by Yunki on 10/12/25.
//

import SwiftUI

struct CalendarHeaderView: View {
    let month: Date
    let onSelectDate: (Date) -> Void
    
    @State private var datePickerPresented: Bool = false
    @State private var newDate: Date = .now
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(month.component(.year))년")
                        .font(.medium_16)
                    
                    HStack(spacing: 9) {
                        Text("\(month.component(.month))월")
                            .font(.semibold_32)
                        
                        Image(systemName: "chevron.right")
                            .bold()
                            .foregroundStyle(.icon)
                            .frame(width: 13, height: 16)
                    }
                }
                .padding(21)
                .foregroundStyle(.textPrimary)
                .onTapGesture {
                    newDate = month
                    datePickerPresented = true
                }
                
                Spacer()
                
                Menu {
                    
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.icon)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .frame(width: 44, height: 44)
                .padding(.trailing, 16)
            }
            
            HStack(spacing: 0) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) {
                    Text($0)
                        .font(.medium_11)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 5)
            
            Rectangle()
                .fill(.mainNeutralSecondary.opacity(0.12))
                .frame(height: 1)
        }
        .sheet(isPresented: $datePickerPresented) {
            NavigationStack {
                DatePicker("", selection: $newDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.init(top: 18, leading: 12, bottom: 18, trailing: 12))
                    .background(RoundedRectangle(cornerRadius: 20).fill(.bgSecondary))
                    .padding(.init(top: 0, leading: 16, bottom: 42, trailing: 16))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                datePickerPresented = false
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        ToolbarItem(placement: .title) {
                            Text("날짜")
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) {
                                onSelectDate(newDate)
                                datePickerPresented = false
                            } label: {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.bgSecondary)
                            }
                            .tint(.mainRed)
                            .buttonStyle(.glassProminent)
                        }
                    }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        
    }
}

#Preview {
    CalendarHeaderView(month: .now, onSelectDate: { _ in })
}
