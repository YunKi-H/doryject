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
            return "B-Day"
        case .delayed:
            return "생리 지연"
        case .unknown:
            return "-"
        }
    }
    
    static func primarySubText(from snapshot: DayInfoCardPrimarySnapshot) -> String? {
        switch snapshot {
        case .delayed(let days):
            return "(\(days)일 지연됨)"
        default:
            return nil
        }
    }
    
    static func secondaryChip(from snapshot: DayInfoCardSecondarySnapshot) -> WidgetChipSnapshot? {
        switch snapshot {
        case .pill(let day, let total):
            if let total {
                return .init(id: "secondary", kind: .secondary, text: "\(day)정 복용/\(total)정", subText: nil)
            }
            return .init(id: "secondary", kind: .secondary, text: "피임약 \(day)일째", subText: nil)
        case .pillBreak(let day, let total):
            return .init(id: "secondary", kind: .secondary, text: "휴약기", subText: "(\(day)일째/\(total)일)")
        case .ovulation:
            return .init(id: "secondary", kind: .secondary, text: "임신 확률 높음", subText: "(배란일)")
        case .fertile:
            return .init(id: "secondary", kind: .secondary, text: "임신 확률 보통", subText: "(가임기)")
        case .notFertile:
            return .init(id: "secondary", kind: .secondary, text: "임신 확률 낮음", subText: nil)
        case .unknown:
            return nil
        }
    }
}
