//
//  WidgetSnapshot.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import Foundation

struct WidgetSnapshot: Codable {
    let generatedAt: Date
    let primaryText: String
    let primarySubText: String?
    let chips: [WidgetChipSnapshot]
    let toggles: WidgetToggleSnapshot
}

struct WidgetChipSnapshot: Codable, Identifiable {
    let id: String
    let kind: WidgetChipKind
    let text: String
    let subText: String?
}

enum WidgetChipKind: String, Codable {
    case secondary
    case love
}

struct WidgetToggleSnapshot: Codable {
    let period: Bool
    let pill: Bool
    let love: Bool
}
