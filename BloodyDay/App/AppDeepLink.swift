//
//  AppDeepLink.swift
//  BloodyDay
//
//  Created by Yunki on 4/19/26.
//

import Foundation

enum AppDeepLink {
    private static let scheme = "bloodyday"
    
    case calendar(date: Date)
    
    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        
        switch url.host {
        case "calendar":
            guard let date = Self.calendarDate(from: url) else { return nil }
            self = .calendar(date: date)
            
        default:
            return nil
        }
    }
    
    static func calendarURL(for date: Date) -> URL? {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date.startOfDay)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }
        
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = "calendar"
        urlComponents.queryItems = [
            URLQueryItem(name: "date", value: String(format: "%04d-%02d-%02d", year, month, day))
        ]
        return urlComponents.url
    }
    
    private static func calendarDate(from url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "date" })?.value else {
            return nil
        }
        
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        
        var dateComponents = DateComponents()
        dateComponents.calendar = .current
        dateComponents.year = parts[0]
        dateComponents.month = parts[1]
        dateComponents.day = parts[2]
        return dateComponents.date?.startOfDay
    }
}
