//
//  DateFormatter+Shared.swift
//  BloodyDay
//
//  Created by Yunki on 12/13/25.
//

import Foundation

extension DateFormatter {
    static let periodList: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()
}
