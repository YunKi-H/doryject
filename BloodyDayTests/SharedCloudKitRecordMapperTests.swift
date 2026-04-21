//
//  SharedCloudKitRecordMapperTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 4/22/26.
//

import CloudKit
import Foundation
import Testing
@testable import BloodyDay

struct SharedCloudKitRecordMapperTests {
    private let zoneID = CKRecordZone.ID(zoneName: "TestSharedZone")
    
    @Test
    func applyOwnedCalendarFields_mapsSettingsAndSharedEventTypesToCalendarRecord() {
        let record = CKRecord(
            recordType: SharedCloudKitSchema.calendarRecordType,
            recordID: CKRecord.ID(recordName: "calendar", zoneID: zoneID)
        )
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 30
        settings.period.averagePeriodDays = 6
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 24
        settings.pill.pillBreakDuration = 4
        
        SharedCloudKitRecordMapper.applyOwnedCalendarFields(
            to: record,
            sharedEventTypes: SharedEventTypeSelection(period: true, pill: false, love: true),
            settings: settings
        )
        
        #expect(record[SharedCloudKitSchema.CalendarField.remoteTitle] as? String == "BloodyDay 캘린더 공유")
        #expect(record[SharedCloudKitSchema.CalendarField.sharedPeriod] as? Bool == true)
        #expect(record[SharedCloudKitSchema.CalendarField.sharedPill] as? Bool == false)
        #expect(record[SharedCloudKitSchema.CalendarField.sharedLove] as? Bool == true)
        #expect(record[SharedCloudKitSchema.CalendarField.autoCyclePredictionEnabled] as? Bool == false)
        #expect((record[SharedCloudKitSchema.CalendarField.averageCycleDays] as? NSNumber)?.intValue == 30)
        #expect((record[SharedCloudKitSchema.CalendarField.averagePeriodDays] as? NSNumber)?.intValue == 6)
        #expect(record[SharedCloudKitSchema.CalendarField.pillEnabled] as? Bool == true)
        #expect(record[SharedCloudKitSchema.CalendarField.pillAutoRecordEnabled] as? Bool == true)
        #expect((record[SharedCloudKitSchema.CalendarField.pillCount] as? NSNumber)?.intValue == 24)
        #expect((record[SharedCloudKitSchema.CalendarField.pillBreakDuration] as? NSNumber)?.intValue == 4)
        
        let calendar = SharedCalendar(record: record)
        #expect(calendar?.id == "calendar")
        #expect(calendar?.remoteTitle == "BloodyDay 캘린더 공유")
        #expect(calendar?.sharedEventTypes == SharedEventTypeSelection(period: true, pill: false, love: true))
        #expect(calendar?.predictionSettings.autoCyclePredictionEnabled == false)
        #expect(calendar?.predictionSettings.averageCycleDays == 30)
        #expect(calendar?.predictionSettings.averagePeriodDays == 6)
        #expect(calendar?.predictionSettings.pillEnabled == true)
        #expect(calendar?.predictionSettings.pillAutoRecordEnabled == true)
        #expect(calendar?.predictionSettings.pillCount == 24)
        #expect(calendar?.predictionSettings.pillBreakDuration == 4)
        #expect(calendar?.permission == .readOnly)
    }
    
    @Test
    func makeOwnedEventRecord_mapsUserEventToSharedCalendarEventRecord() throws {
        let calendarRecord = CKRecord(
            recordType: SharedCloudKitSchema.calendarRecordType,
            recordID: CKRecord.ID(recordName: "calendar", zoneID: zoneID)
        )
        let eventID = try #require(UUID(uuidString: "3F587315-0B76-4EB4-BC15-D1892C4C8E5A"))
        let eventDate = makeDate(2026, 4, 22, hour: 13)
        let event = UserEvent(id: eventID, date: eventDate, type: .pill, calendar: calendar)
        
        let record = SharedCloudKitRecordMapper.makeOwnedEventRecord(
            from: event,
            calendarRecord: calendarRecord,
            zoneID: zoneID
        )
        
        #expect(record.recordType == SharedCloudKitSchema.eventRecordType)
        #expect(record.recordID.recordName == "owned-event-\(eventID.uuidString)")
        #expect(record.recordID.zoneID == zoneID)
        #expect((record[SharedCloudKitSchema.EventField.calendarReference] as? CKRecord.Reference)?.recordID == calendarRecord.recordID)
        #expect(record[SharedCloudKitSchema.EventField.sourceEventId] as? String == eventID.uuidString)
        #expect(record[SharedCloudKitSchema.EventField.typeRaw] as? String == EventType.pill.rawValue)
        #expect(record[SharedCloudKitSchema.EventField.date] as? Date == eventDate.startOfDay)
        #expect(record[SharedCloudKitSchema.EventField.updatedAt] as? Date != nil)
        #expect(record[SharedCloudKitSchema.EventField.deletedAt] == nil)
        
        let sharedEvent = SharedCalendarEvent(record: record)
        #expect(sharedEvent?.id == "owned-event-\(eventID.uuidString)")
        #expect(sharedEvent?.calendarId == "calendar")
        #expect(sharedEvent?.sourceEventId == eventID.uuidString)
        #expect(sharedEvent?.type == .pill)
        #expect(sharedEvent?.date == eventDate.startOfDay)
        #expect(sharedEvent?.isDeleted == false)
    }
    
    @Test
    func recordInitializersRejectUnexpectedRecordTypes() {
        let record = CKRecord(
            recordType: "Unexpected",
            recordID: CKRecord.ID(recordName: "unexpected", zoneID: zoneID)
        )
        
        #expect(SharedCalendar(record: record) == nil)
        #expect(SharedCalendarEvent(record: record) == nil)
    }
    
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date ?? Date()
    }
}
