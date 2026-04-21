//
//  CloudSharingService.swift
//  BloodyDay
//
//  Created by Yunki on 4/21/26.
//

import CloudKit
import Foundation

enum CloudSharingAvailability: Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

protocol CloudSharingService {
    func fetchAvailability() async -> CloudSharingAvailability
    func accept(_ metadata: CKShare.Metadata) async throws
    func fetchSharedSnapshot() async throws -> SharedCalendarSnapshot
}

struct SharedCalendarSnapshot {
    let calendars: [SharedCalendar]
    let eventsByCalendarId: [String: [SharedCalendarEvent]]
}

final class CloudKitSharingService: CloudSharingService {
    static let acceptedShareNotification = Notification.Name("CloudKitSharingService.acceptedShare")
    static let containerIdentifier = "iCloud.dorypawn.BDay"
    
    private let container: CKContainer
    private let sharedDatabase: CKDatabase
    
    init(containerIdentifier: String = CloudKitSharingService.containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.sharedDatabase = container.sharedCloudDatabase
    }
    
    func fetchAvailability() async -> CloudSharingAvailability {
        do {
            let status = try await accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            case .couldNotDetermine:
                return .couldNotDetermine
            @unknown default:
                return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }
    
    func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.accept(metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                NotificationCenter.default.post(
                    name: Self.acceptedShareNotification,
                    object: nil,
                    userInfo: ["metadata": metadata]
                )
                continuation.resume(returning: ())
            }
        }
    }
    
    func fetchSharedSnapshot() async throws -> SharedCalendarSnapshot {
        let calendarRecords = try await fetchAllRecords(
            matching: CKQuery(
                recordType: SharedCloudKitSchema.calendarRecordType,
                predicate: NSPredicate(value: true)
            )
        )
        let eventRecords = try await fetchAllRecords(
            matching: CKQuery(
                recordType: SharedCloudKitSchema.eventRecordType,
                predicate: NSPredicate(value: true)
            )
        )
        
        let calendars = calendarRecords.compactMap { SharedCalendar(record: $0) }
        let validCalendarIDs = Set(calendars.map(\.id))
        
        let events = eventRecords.compactMap { SharedCalendarEvent(record: $0) }
            .filter { validCalendarIDs.contains($0.calendarId) }
        let eventsByCalendarId = Dictionary(grouping: events, by: \.calendarId)
        
        return SharedCalendarSnapshot(
            calendars: calendars.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending },
            eventsByCalendarId: eventsByCalendarId
        )
    }
    
    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    private func fetchAllRecords(matching query: CKQuery) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var response = try await sharedDatabase.records(matching: query)
        records.append(contentsOf: response.matchResults.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return record
        })
        
        while let cursor = response.queryCursor {
            response = try await sharedDatabase.records(continuingMatchFrom: cursor)
            records.append(contentsOf: response.matchResults.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return record
            })
        }
        
        return records
    }
}

private enum SharedCloudKitSchema {
    static let calendarRecordType = "SharedCalendar"
    static let eventRecordType = "SharedCalendarEvent"
    
    enum CalendarField {
        static let ownerDisplayName = "ownerDisplayName"
        static let remoteTitle = "remoteTitle"
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

private extension SharedCalendar {
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
            updatedAt: record.modificationDate
        )
    }
}

private extension SharedCalendarEvent {
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
