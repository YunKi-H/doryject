//
//  AppDeepLinkTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/19/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct AppDeepLinkTests {
    @Test
    func calendarURLParsesCalendarDate() throws {
        let url = try #require(URL(string: "bloodyday://calendar?date=2026-04-29"))
        let deepLink = try #require(AppDeepLink(url: url))
        
        guard case .calendar(let date) = deepLink else {
            Issue.record("Expected calendar deep link")
            return
        }
        
        #expect(date == makeDate(2026, 4, 29))
    }
    
    @Test
    func calendarURLBuilderUsesParseableDateFormat() throws {
        let url = try #require(AppDeepLink.calendarURL(for: makeDate(2026, 4, 29)))
        
        #expect(url.absoluteString == "bloodyday://calendar?date=2026-04-29")
        #expect(AppDeepLink(url: url) != nil)
    }
    
    @Test
    func invalidCalendarDateReturnsNil() throws {
        let url = try #require(URL(string: "bloodyday://calendar?date=2026-02-31"))
        
        #expect(AppDeepLink(url: url) == nil)
    }
    
    @Test
    func unsupportedDeepLinksReturnNil() throws {
        let unsupportedScheme = try #require(URL(string: "https://calendar?date=2026-04-29"))
        let unsupportedHost = try #require(URL(string: "bloodyday://settings?date=2026-04-29"))
        let missingDate = try #require(URL(string: "bloodyday://calendar"))
        
        #expect(AppDeepLink(url: unsupportedScheme) == nil)
        #expect(AppDeepLink(url: unsupportedHost) == nil)
        #expect(AppDeepLink(url: missingDate) == nil)
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = .current
        components.year = year
        components.month = month
        components.day = day
        return components.date!.startOfDay
    }
}
