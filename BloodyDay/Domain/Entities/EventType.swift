//
//  EventType.swift
//  BloodyDay
//
//  Created by Yunki on 10/11/25.
//

import Foundation

enum EventType: String, CaseIterable {
    case period // 생리기간
    case ovulation // 배란일
    case fertile // 가임기
    case pill
    case love
}
