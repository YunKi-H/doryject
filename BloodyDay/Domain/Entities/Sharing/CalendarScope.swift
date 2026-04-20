//
//  CalendarScope.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import Foundation

enum CalendarScope: Codable, Equatable, Hashable {
    case mine
    case shared(id: String)
    
    var isEditable: Bool {
        self == .mine
    }
    
    var fallbackDisplayName: String {
        switch self {
        case .mine:
            return "내 캘린더"
        case .shared:
            return "공유 캘린더"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case kind
        case id
    }
    
    private enum Kind: String, Codable {
        case mine
        case shared
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .mine
        
        switch kind {
        case .mine:
            self = .mine
        case .shared:
            if let id = try container.decodeIfPresent(String.self, forKey: .id), id.isEmpty == false {
                self = .shared(id: id)
            } else {
                self = .mine
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .mine:
            try container.encode(Kind.mine, forKey: .kind)
        case .shared(let id):
            try container.encode(Kind.shared, forKey: .kind)
            try container.encode(id, forKey: .id)
        }
    }
}
