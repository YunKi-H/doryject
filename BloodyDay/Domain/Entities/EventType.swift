//
//  EventType.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import Foundation

enum EventType: String, Equatable, Hashable, Codable {
    case period // 생리기간
    case ovulation // 배란일
    case fertile // 가임기
    case pill
    case love
    
    var isCycleRelated: Bool {
        switch self {
        case .period, .ovulation, .fertile: return true
        case .pill, .love: return false
        @unknown default : return false
        }
    }
}
