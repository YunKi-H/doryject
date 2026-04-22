//
//  SharedCloudKitRecordMapper.swift
//  BloodyDay
//
//  Created by Yunki on 4/22/26.
//

import CloudKit
import Foundation

enum SharedCloudKitSchema {
    static let calendarRecordType = "SharedCalendar"
    static let eventRecordType = "SharedCalendarEvent"
    
    enum CalendarField {
        static let ownerDisplayName = "ownerDisplayName"
        static let remoteTitle = "remoteTitle"
        static let shareRecordName = "shareRecordName"
        static let sharedPeriod = "sharedPeriod"
        static let sharedPill = "sharedPill"
        static let sharedLove = "sharedLove"
        static let autoCyclePredictionEnabled = "autoCyclePredictionEnabled"
        static let averageCycleDays = "averageCycleDays"
        static let averagePeriodDays = "averagePeriodDays"
        static let pillEnabled = "pillEnabled"
        static let pillAutoRecordEnabled = "pillAutoRecordEnabled"
        static let pillCount = "pillCount"
        static let pillBreakDuration = "pillBreakDuration"
    }
    
    enum EventField {
        static let calendarReference = "calendarReference"
        static let sourceEventId = "sourceEventId"
        static let typeRaw = "typeRaw"
        static let date = "date"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
    }
}

enum SharedCloudKitRecordMapper {
    static func applyOwnedCalendarFields(
        to record: CKRecord,
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings
    ) {
        record[SharedCloudKitSchema.CalendarField.ownerDisplayName] = nil
        record[SharedCloudKitSchema.CalendarField.remoteTitle] = "BloodyDay 캘린더 공유" as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.sharedPeriod] = sharedEventTypes.period as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.sharedPill] = sharedEventTypes.pill as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.sharedLove] = sharedEventTypes.love as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.autoCyclePredictionEnabled] = settings.period.autoCyclePredictionEnabled as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.averageCycleDays] = settings.period.averageCycleDays.map(NSNumber.init(value:))
        record[SharedCloudKitSchema.CalendarField.averagePeriodDays] = settings.period.averagePeriodDays.map(NSNumber.init(value:))
        record[SharedCloudKitSchema.CalendarField.pillEnabled] = settings.pill.pillEnabled as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.pillAutoRecordEnabled] = settings.pill.pillAutoRecordEnabled as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.pillCount] = settings.pill.pillCount as CKRecordValue
        record[SharedCloudKitSchema.CalendarField.pillBreakDuration] = settings.pill.pillBreakDuration as CKRecordValue
    }
    
    static func makeOwnedEventRecord(from event: UserEvent, calendarRecord: CKRecord, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: SharedCloudKitSchema.eventRecordType,
            recordID: makeOwnedEventRecordID(for: event.id, zoneID: zoneID)
        )
        let reference = CKRecord.Reference(recordID: calendarRecord.recordID, action: .none)
        record[SharedCloudKitSchema.EventField.calendarReference] = reference
        record[SharedCloudKitSchema.EventField.sourceEventId] = event.id.uuidString as CKRecordValue
        record[SharedCloudKitSchema.EventField.typeRaw] = event.type.rawValue as CKRecordValue
        record[SharedCloudKitSchema.EventField.date] = event.date.startOfDay as CKRecordValue
        record[SharedCloudKitSchema.EventField.updatedAt] = Date() as CKRecordValue
        record[SharedCloudKitSchema.EventField.deletedAt] = nil
        return record
    }
    
    static func makeOwnedEventRecordID(for sourceEventID: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(
            recordName: "owned-event-\(sourceEventID.uuidString)",
            zoneID: zoneID
        )
    }
}

extension SharedCalendar {
    init?(record: CKRecord) {
        guard record.recordType == SharedCloudKitSchema.calendarRecordType else { return nil }
        
        self.init(
            id: record.recordID.recordName,
            ownerDisplayName: record[SharedCloudKitSchema.CalendarField.ownerDisplayName] as? String,
            remoteTitle: record[SharedCloudKitSchema.CalendarField.remoteTitle] as? String,
            sharedEventTypes: SharedEventTypeSelection(
                period: record[SharedCloudKitSchema.CalendarField.sharedPeriod] as? Bool ?? false,
                pill: record[SharedCloudKitSchema.CalendarField.sharedPill] as? Bool ?? false,
                love: record[SharedCloudKitSchema.CalendarField.sharedLove] as? Bool ?? false
            ),
            predictionSettings: SharedCalendarPredictionSettings(
                autoCyclePredictionEnabled: record[SharedCloudKitSchema.CalendarField.autoCyclePredictionEnabled] as? Bool ?? true,
                averageCycleDays: (record[SharedCloudKitSchema.CalendarField.averageCycleDays] as? NSNumber)?.intValue,
                averagePeriodDays: (record[SharedCloudKitSchema.CalendarField.averagePeriodDays] as? NSNumber)?.intValue,
                pillEnabled: record[SharedCloudKitSchema.CalendarField.pillEnabled] as? Bool ?? false,
                pillAutoRecordEnabled: record[SharedCloudKitSchema.CalendarField.pillAutoRecordEnabled] as? Bool ?? false,
                pillCount: (record[SharedCloudKitSchema.CalendarField.pillCount] as? NSNumber)?.intValue ?? 21,
                pillBreakDuration: (record[SharedCloudKitSchema.CalendarField.pillBreakDuration] as? NSNumber)?.intValue ?? 7
            ),
            permission: .readOnly,
            acceptedAt: record.creationDate,
            updatedAt: record.modificationDate,
            cloudRecordName: record.recordID.recordName,
            cloudZoneName: record.recordID.zoneID.zoneName,
            cloudOwnerName: record.recordID.zoneID.ownerName,
            cloudShareRecordName: record[SharedCloudKitSchema.CalendarField.shareRecordName] as? String
        )
    }
}

extension SharedCalendarEvent {
    init?(record: CKRecord) {
        guard record.recordType == SharedCloudKitSchema.eventRecordType,
              let reference = record[SharedCloudKitSchema.EventField.calendarReference] as? CKRecord.Reference,
              let typeRaw = record[SharedCloudKitSchema.EventField.typeRaw] as? String,
              let type = EventType(rawValue: typeRaw),
              let date = record[SharedCloudKitSchema.EventField.date] as? Date else {
            return nil
        }
        
        self.init(
            id: record.recordID.recordName,
            calendarId: reference.recordID.recordName,
            sourceEventId: record[SharedCloudKitSchema.EventField.sourceEventId] as? String,
            type: type,
            date: date,
            updatedAt: (record[SharedCloudKitSchema.EventField.updatedAt] as? Date) ?? record.modificationDate ?? Date(),
            deletedAt: record[SharedCloudKitSchema.EventField.deletedAt] as? Date
        )
    }
}
