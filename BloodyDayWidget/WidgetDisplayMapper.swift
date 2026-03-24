//
//  WidgetDisplayMapper.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/22/26.
//

import Foundation

enum WidgetDisplayMapper {
    static func primaryText(from snapshot: DayInfoCardPrimarySnapshot) -> String {
        switch snapshot {
        case .countdown(let days):
            return "B-\(days)"
        case .ongoing(let day):
            return "B+\(day)"
        case .bDay:
            return "B-DAY"
        case .delayed:
            return "생리 지연"
        case .unknown:
            return "B-DAY"
        }
    }
    
    static func primarySubText(
        from snapshot: DayInfoCardPrimarySnapshot,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        switch snapshot {
        case .countdown(let days):
            guard let expectedDate = calendar.date(byAdding: .day, value: days, to: referenceDate.startOfDay) else {
                return nil
            }
            return "(\(monthDayText(for: expectedDate)) 예정)"
        case .ongoing(let day):
            guard let startDate = calendar.date(byAdding: .day, value: -(max(day - 1, 0)), to: referenceDate.startOfDay) else {
                return nil
            }
            return "(\(monthDayText(for: startDate)) 시작)"
        case .delayed(let days):
            guard let startDate = calendar.date(byAdding: .day, value: -days, to: referenceDate.startOfDay) else {
                return nil
            }
            return "(\(monthDayText(for: startDate)) 시작)"
        case .bDay:
            return nil
        default:
            return nil
        }
    }
    
    static func secondaryChip(from snapshot: DayInfoCardSecondarySnapshot) -> WidgetChipSnapshot? {
        switch snapshot {
        case .pill(let day, let total):
            if let total {
                return .init(id: "pill", kind: .pill, text: "(\(day)/\(total))")
            }
            return .init(id: "pill", kind: .pill, text: "(\(day))")
        case .pillBreak(let day, let total):
            return .init(id: "pill", kind: .pill, text: "휴약기 (\(day)/\(total))")
        case .ovulation:
            return .init(id: "fertility", kind: .fertility, text: "매우높음")
        case .fertile:
            return .init(id: "fertility", kind: .fertility, text: "높음")
        case .notFertile:
            return nil
        case .unknown:
            return nil
        }
    }

    static func periodChip(from snapshot: DayInfoCardPrimarySnapshot) -> WidgetChipSnapshot? {
        switch snapshot {
        case .ongoing, .bDay:
            return .init(id: "period", kind: .period, text: "진행")
        case .delayed:
            return .init(id: "period", kind: .period, text: "지연")
        case .countdown, .unknown:
            return nil
        }
    }

    private static func monthDayText(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .month(.defaultDigits)
                .day(.defaultDigits)
        )
    }
}
