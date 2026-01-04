//
//  PeriodListView.swift
//  BloodyDay
//
//  Created by Yunki on 12/13/25.
//

import SwiftUI
import SwiftData

struct PeriodListView: View {
    @Query(filter: #Predicate<UserEvent> { $0.typeRaw == "period" }, sort: \UserEvent.date)
    private var periodEvents: [UserEvent]
    
    @State private var editSheetIsPresented: Bool = false
    @State private var settingSheetIsPresented: Bool = false

    private var periodSummaries: [PeriodSummary] {
        buildPeriodSummaries(from: periodEvents.map { $0.date })
    }

    private var lastPeriodStartText: String {
        guard let lastStart = periodSummaries.last?.start else { return "기록 없음" }
        return formatDate(lastStart)
    }

    private var lastPeriodRangeText: String {
        guard let last = periodSummaries.last else { return "기록 없음" }
        return "\(formatDate(last.start)) - \(formatDate(last.end))"
    }

    private var averagePeriodText: String {
        let lengths = periodSummaries.map(\.lengthDays)
        guard !lengths.isEmpty else { return "-" }
        let avg = Double(lengths.reduce(0, +)) / Double(lengths.count)
        return "\(Int(round(avg)))일"
    }

    private var averageCycleText: String {
        let cycles = periodSummaries.compactMap(\.cycleDays)
        guard !cycles.isEmpty else { return "-" }
        let avg = Double(cycles.reduce(0, +)) / Double(cycles.count)
        return "\(Int(round(avg)))일"
    }
    
    var body: some View {
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
                            Text(lastPeriodStartText == "기록 없음" ? "-" : lastPeriodStartText)
                                .font(.semibold_18)
                        }
                        .foregroundStyle(.textPrimary)
                        
                        Text(lastPeriodRangeText)
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
                        Text(averagePeriodText)
                            .font(.semibold_18)
                    }
                    .foregroundStyle(.textPrimary)
                    
                    HStack {
                        Text("평균 주기")
                            .font(.regular_18)
                        Spacer()
                        Text(averageCycleText)
                            .font(.semibold_18)
                    }
                    .foregroundStyle(.textPrimary)
                }
                .listRowBackground(Color.bgSecondary)
                
                Section {
                    ForEach(periodSummaries.reversed()) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(formatDate(summary.start)) - \(formatDate(summary.end))")
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
        .sheet(isPresented: $editSheetIsPresented) {
            PeriodEditSheetView()
        }
        .sheet(isPresented: $settingSheetIsPresented) {
            PeriodSettingSheetView()
        }
    }
}

private struct PeriodSummary: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let lengthDays: Int
    let cycleDays: Int?
}

private func buildPeriodSummaries(from dates: [Date]) -> [PeriodSummary] {
    let calendar = Calendar.current
    let normalized = Array(Set(dates.map { $0.startOfDay })).sorted()
    guard !normalized.isEmpty else { return [] }

    var segments: [(start: Date, end: Date)] = []
    var currentStart = normalized[0]
    var currentEnd = normalized[0]

    for date in normalized.dropFirst() {
        let expectedNext = calendar.date(byAdding: .day, value: 1, to: currentEnd)!
        if calendar.isDate(date, inSameDayAs: expectedNext) {
            currentEnd = date
        } else {
            segments.append((start: currentStart, end: currentEnd))
            currentStart = date
            currentEnd = date
        }
    }
    segments.append((start: currentStart, end: currentEnd))

    var summaries: [PeriodSummary] = []
    for idx in segments.indices {
        let start = segments[idx].start
        let end = segments[idx].end
        let length = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let lengthDays = max(length + 1, 1)
        let cycleDays: Int?
        if idx == 0 {
            cycleDays = nil
        } else {
            let prevStart = segments[idx - 1].start
            let cycle = calendar.dateComponents([.day], from: prevStart, to: start).day ?? 0
            cycleDays = cycle > 0 ? cycle : nil
        }

        summaries.append(
            PeriodSummary(
                start: start,
                end: end,
                lengthDays: lengthDays,
                cycleDays: cycleDays
            )
        )
    }

    return summaries
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale.current
    formatter.dateFormat = "yyyy년 M월 d일"
    return formatter.string(from: date)
}

#Preview {
    NavigationStack {
        PeriodListView()
    }
}
