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

enum CloudSharingError: LocalizedError {
    case shareSaveFailed
    case missingShareURL
    
    var errorDescription: String? {
        switch self {
        case .shareSaveFailed:
            return "공유 정보를 iCloud에 저장하지 못했어요."
        case .missingShareURL:
            return "iCloud 공유 링크를 생성하지 못했어요."
        }
    }
}

protocol CloudSharingService {
    func fetchAvailability() async -> CloudSharingAvailability
    func accept(_ metadata: CKShare.Metadata) async throws
    func fetchSharedSnapshot() async throws -> SharedCalendarSnapshot
    func fetchOwnedShare() async throws -> CKShare?
    func prepareOwnedShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> CKShare
}

struct SharedCalendarSnapshot {
    let calendars: [SharedCalendar]
    let eventsByCalendarId: [String: [SharedCalendarEvent]]
}

final class CloudKitSharingService: CloudSharingService {
    static let acceptedShareNotification = Notification.Name("CloudKitSharingService.acceptedShare")
    static let containerIdentifier = "iCloud.dorypawn.BDaySharing"
    static let ownedZoneName = "BloodyDaySharedCalendar"
    static let ownedCalendarRecordName = "owned-shared-calendar"
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    init(containerIdentifier: String = CloudKitSharingService.containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
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
        let sharedZoneIDs = try await fetchSharedZoneIDs()
        let calendarRecords = try await fetchAllSharedRecords(
            recordType: SharedCloudKitSchema.calendarRecordType,
            zoneIDs: sharedZoneIDs
        )
        let eventRecords = try await fetchAllSharedRecords(
            recordType: SharedCloudKitSchema.eventRecordType,
            zoneIDs: sharedZoneIDs
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
    
    func fetchOwnedShare() async throws -> CKShare? {
        let recordID = CKRecord.ID(
            recordName: Self.ownedCalendarRecordName,
            zoneID: ownedZoneID
        )
        let fetched: [CKRecord.ID: Result<CKRecord, Error>]
        do {
            fetched = try await privateDatabase.records(for: [recordID])
        } catch let error as CKError where error.code == .zoneNotFound {
            return nil
        }
        
        guard case .success(let rootRecord)? = fetched[recordID] else { return nil }
        return try await fetchOwnedShare(for: rootRecord)
    }
    
    func prepareOwnedShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> CKShare {
        try await ensureOwnedZoneExists()
        let rootRecord = try await fetchOrMakeOwnedCalendarRecord()
        applyOwnedCalendarFields(
            to: rootRecord,
            sharedEventTypes: sharedEventTypes,
            settings: settings
        )
        
        let existingShare = try await fetchOwnedShare(for: rootRecord)
        let share = existingShare ?? CKShare(rootRecord: rootRecord)
        rootRecord[SharedCloudKitSchema.CalendarField.shareRecordName] = share.recordID.recordName as CKRecordValue
        share[CKShare.SystemFieldKey.title] = "BloodyDay 캘린더 공유" as CKRecordValue
        share.publicPermission = .none

        let result = try await privateDatabase.modifyRecords(
            saving: [rootRecord, share],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
        
        let savedShareResult = result.saveResults[share.recordID]
        guard let savedShareResult else {
            throw CloudSharingError.shareSaveFailed
        }
        
        guard case .success(let savedShareRecord) = savedShareResult,
              let savedShare = savedShareRecord as? CKShare else {
            throw CloudSharingError.shareSaveFailed
        }
        
        let fetchedShare = try await fetchShare(recordID: savedShare.recordID)
        let resolvedShare = fetchedShare ?? savedShare
        guard resolvedShare.url != nil else {
            throw CloudSharingError.missingShareURL
        }
        
        await syncOwnedEventRecords(
            events: events,
            sharedEventTypes: sharedEventTypes,
            calendarRecord: rootRecord
        )
        return resolvedShare
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
    
    private var ownedZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.ownedZoneName)
    }
    
    private func fetchSharedZoneIDs() async throws -> [CKRecordZone.ID] {
        var zoneIDs = try await sharedDatabase.databaseChanges(since: nil).modifications.map(\.zoneID)
        zoneIDs.removeAll { $0.zoneName == CKRecordZone.ID.defaultZoneName }
        return zoneIDs
    }
    
    private func fetchAllSharedRecords(recordType: CKRecord.RecordType, zoneIDs: [CKRecordZone.ID]) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        for zoneID in zoneIDs {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            records.append(contentsOf: try await fetchAllRecords(matching: query, database: sharedDatabase, zoneID: zoneID))
        }
        return records
    }
    
    private func fetchAllRecords(matching query: CKQuery, database: CKDatabase, zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var response = try await database.records(matching: query, inZoneWith: zoneID)
        records.append(contentsOf: response.matchResults.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return record
        })
        
        while let cursor = response.queryCursor {
            response = try await database.records(continuingMatchFrom: cursor)
            records.append(contentsOf: response.matchResults.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return record
            })
        }
        
        return records
    }
    
    private func ensureOwnedZoneExists() async throws {
        let result = try await privateDatabase.recordZones(for: [ownedZoneID])
        if case .success? = result[ownedZoneID] {
            return
        }
        _ = try await privateDatabase.modifyRecordZones(
            saving: [CKRecordZone(zoneID: ownedZoneID)],
            deleting: []
        )
    }
    
    private func fetchOrMakeOwnedCalendarRecord() async throws -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: Self.ownedCalendarRecordName,
            zoneID: ownedZoneID
        )
        let fetched = try await privateDatabase.records(for: [recordID])
        if case .success(let record)? = fetched[recordID] {
            return record
        }
        return CKRecord(
            recordType: SharedCloudKitSchema.calendarRecordType,
            recordID: recordID
        )
    }
    
    private func fetchOwnedShare(for rootRecord: CKRecord) async throws -> CKShare? {
        if let shareRecordName = rootRecord[SharedCloudKitSchema.CalendarField.shareRecordName] as? String {
            return try await fetchShare(
                recordID: CKRecord.ID(
                    recordName: shareRecordName,
                    zoneID: rootRecord.recordID.zoneID
                )
            )
        }
        
        guard let shareReference = rootRecord[CKRecord.SystemFieldKey.share] as? CKRecord.Reference else {
            return nil
        }
        return try await fetchShare(recordID: shareReference.recordID)
    }
    
    private func fetchShare(recordID: CKRecord.ID) async throws -> CKShare? {
        let fetched = try await privateDatabase.records(for: [recordID])
        guard case .success(let record)? = fetched[recordID] else { return nil }
        return record as? CKShare
    }
    
    private func fetchOwnedEventRecords() async throws -> [CKRecord] {
        let records = try await fetchAllRecords(
            matching: CKQuery(
                recordType: SharedCloudKitSchema.eventRecordType,
                predicate: NSPredicate(value: true)
            ),
            database: privateDatabase,
            zoneID: ownedZoneID
        )
        return records.filter {
            (($0[SharedCloudKitSchema.EventField.calendarReference] as? CKRecord.Reference)?.recordID.recordName == Self.ownedCalendarRecordName)
        }
    }
    
    private func syncOwnedEventRecords(
        events: [UserEvent],
        sharedEventTypes: SharedEventTypeSelection,
        calendarRecord: CKRecord
    ) async {
        let sharedEvents = events.filter { sharedEventTypes.contains($0.type) }
        let desiredRecordIDs = Set(sharedEvents.map(\.id).map(makeOwnedEventRecordID(for:)))
        let existingEventRecords = (try? await fetchOwnedEventRecords()) ?? []
        let staleRecordIDs = existingEventRecords
            .map(\.recordID)
            .filter { desiredRecordIDs.contains($0) == false }
        let eventRecords = sharedEvents
            .map { makeOwnedEventRecord(from: $0, calendarRecord: calendarRecord) }
        guard eventRecords.isEmpty == false || staleRecordIDs.isEmpty == false else { return }
        
        do {
            _ = try await privateDatabase.modifyRecords(
                saving: eventRecords,
                deleting: staleRecordIDs,
                savePolicy: .changedKeys,
                atomically: false
            )
        } catch {
            // Sharing can still proceed even if event mirroring needs a later retry.
        }
    }
    
    private func applyOwnedCalendarFields(
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
    
    private func makeOwnedEventRecord(from event: UserEvent, calendarRecord: CKRecord) -> CKRecord {
        let record = CKRecord(
            recordType: SharedCloudKitSchema.eventRecordType,
            recordID: makeOwnedEventRecordID(for: event.id)
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
    
    private func makeOwnedEventRecordID(for sourceEventID: UUID) -> CKRecord.ID {
        CKRecord.ID(
            recordName: "owned-event-\(sourceEventID.uuidString)",
            zoneID: ownedZoneID
        )
    }
}

private enum SharedCloudKitSchema {
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
