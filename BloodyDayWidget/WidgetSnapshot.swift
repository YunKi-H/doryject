//
//  WidgetSnapshot.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    let generatedAt: Date
    let primaryText: String
    let primarySubText: String?
    let chips: [WidgetChipSnapshot]
    let toggles: WidgetToggleSnapshot
}

struct WidgetChipSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let kind: WidgetChipKind
    let text: String
}

enum WidgetChipKind: String, Codable, Equatable {
    case period
    case pill
    case fertility
}

struct WidgetToggleSnapshot: Codable, Equatable {
    let period: Bool
    let pill: Bool
    let love: Bool
}
