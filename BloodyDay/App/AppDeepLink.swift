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
        let calendarDay = CalendarDay(
            date: date,
            calendar: Calendar.autoupdatingCurrent
        )
        
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = "calendar"
        urlComponents.queryItems = [
            URLQueryItem(name: "date", value: calendarDay.dateString)
        ]
        return urlComponents.url
    }
    
    private static func calendarDate(from url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "date" })?.value else {
            return nil
        }
        
        let parts = value.split(
            separator: "-",
            omittingEmptySubsequences: false
        )
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              let calendarDay = CalendarDay(
                year: year,
                month: month,
                day: day
              ) else {
            return nil
        }
        return calendarDay.date(in: Calendar.autoupdatingCurrent)
    }
}
