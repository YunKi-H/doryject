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
    case missingSharedCalendarReference
    
    var errorDescription: String? {
        switch self {
        case .shareSaveFailed:
            return "공유 정보를 iCloud에 저장하지 못했어요."
        case .missingShareURL:
            return "iCloud 공유 링크를 생성하지 못했어요."
        case .missingSharedCalendarReference:
            return "공유 캘린더 정보를 찾지 못했어요."
        }
    }
}

protocol CloudSharingService {
    var containerIdentifier: String { get }
    
    func fetchAvailability() async -> CloudSharingAvailability
    func accept(_ metadata: CKShare.Metadata) async throws
    func fetchSharedSnapshot() async throws -> SharedCalendarSnapshot
    func fetchOwnedShare() async throws -> CKShare?
    func stopOwnedSharing() async throws
    func leaveSharedCalendar(_ calendar: SharedCalendar) async throws
    func prepareOwnedShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> PreparedCloudShare
}

struct SharedCalendarSnapshot {
    let calendars: [SharedCalendar]
    let eventsByCalendarId: [String: [SharedCalendarEvent]]
}

struct PreparedCloudShare {
    let share: CKShare
    let eventSyncResult: CloudSharingEventSyncResult
}

enum CloudSharingEventSyncResult: Equatable {
    case synced
    case partiallyFailed
    case failed
}

final class CloudKitSharingService: CloudSharingService {
    static let containerIdentifier = "iCloud.dorypawn.BDaySharing"
    static let ownedZoneName = "BloodyDaySharedCalendar"
    static let ownedCalendarRecordName = "owned-shared-calendar"
    
    let containerIdentifier: String
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    init(containerIdentifier: String = CloudKitSharingService.containerIdentifier) {
        self.containerIdentifier = containerIdentifier
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
    
    func stopOwnedSharing() async throws {
        let rootRecordID = CKRecord.ID(
            recordName: Self.ownedCalendarRecordName,
            zoneID: ownedZoneID
        )
        let fetched: [CKRecord.ID: Result<CKRecord, Error>]
        do {
            fetched = try await privateDatabase.records(for: [rootRecordID])
        } catch let error as CKError where error.code == .zoneNotFound {
            return
        }
        
        guard case .success(let rootRecord)? = fetched[rootRecordID] else { return }
        let share = try await fetchOwnedShare(for: rootRecord)
        let eventRecordIDs = (try? await fetchOwnedEventRecords().map(\.recordID)) ?? []
        var deletingRecordIDs = eventRecordIDs
        if let share {
            deletingRecordIDs.append(share.recordID)
        }
        deletingRecordIDs.append(rootRecord.recordID)
        
        _ = try await privateDatabase.modifyRecords(
            saving: [],
            deleting: deletingRecordIDs,
            savePolicy: .changedKeys,
            atomically: false
        )
    }
    
    func leaveSharedCalendar(_ calendar: SharedCalendar) async throws {
        guard let shareRecordName = calendar.cloudShareRecordName,
              let zoneName = calendar.cloudZoneName,
              let ownerName = calendar.cloudOwnerName else {
            throw CloudSharingError.missingSharedCalendarReference
        }
        
        let shareRecordID = CKRecord.ID(
            recordName: shareRecordName,
            zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        )
        _ = try await sharedDatabase.deleteRecord(withID: shareRecordID)
    }
    
    func prepareOwnedShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings,
        events: [UserEvent]
    ) async throws -> PreparedCloudShare {
        let preparedRootShare = try await prepareOwnedRootShare(
            sharedEventTypes: sharedEventTypes,
            settings: settings
        )
        
        let eventSyncResult = await syncOwnedEventRecords(
            events: events,
            sharedEventTypes: sharedEventTypes,
            calendarRecord: preparedRootShare.rootRecord
        )
        return PreparedCloudShare(
            share: preparedRootShare.share,
            eventSyncResult: eventSyncResult
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
    
    private struct PreparedOwnedRootShare {
        let rootRecord: CKRecord
        let share: CKShare
    }
    
    private func prepareOwnedRootShare(
        sharedEventTypes: SharedEventTypeSelection,
        settings: UserSettings
    ) async throws -> PreparedOwnedRootShare {
        try await ensureOwnedZoneExists()
        let rootRecord = try await fetchOrMakeOwnedCalendarRecord()
        SharedCloudKitRecordMapper.applyOwnedCalendarFields(
            to: rootRecord,
            sharedEventTypes: sharedEventTypes,
            settings: settings
        )
        
        let share = try await resolveOwnedShare(for: rootRecord)
        let savedShare = try await saveOwnedRootShare(
            rootRecord: rootRecord,
            share: share
        )
        return PreparedOwnedRootShare(
            rootRecord: rootRecord,
            share: savedShare
        )
    }
    
    private func resolveOwnedShare(for rootRecord: CKRecord) async throws -> CKShare {
        let share = try await fetchOwnedShare(for: rootRecord) ?? CKShare(rootRecord: rootRecord)
        rootRecord[SharedCloudKitSchema.CalendarField.shareRecordName] = share.recordID.recordName as CKRecordValue
        share[CKShare.SystemFieldKey.title] = "BloodyDay 캘린더 공유" as CKRecordValue
        share.publicPermission = .none
        return share
    }
    
    private func saveOwnedRootShare(rootRecord: CKRecord, share: CKShare) async throws -> CKShare {
        let result = try await privateDatabase.modifyRecords(
            saving: [rootRecord, share],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
        
        let savedShareResult = result.saveResults[share.recordID]
        guard let savedShareResult,
              case .success(let savedShareRecord) = savedShareResult,
              let savedShare = savedShareRecord as? CKShare else {
            throw CloudSharingError.shareSaveFailed
        }
        
        let fetchedShare = try await fetchShare(recordID: savedShare.recordID)
        let resolvedShare = fetchedShare ?? savedShare
        guard resolvedShare.url != nil else {
            throw CloudSharingError.missingShareURL
        }
        return resolvedShare
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
    ) async -> CloudSharingEventSyncResult {
        let sharedEvents = events.filter { sharedEventTypes.contains($0.type) }
        let desiredRecordIDs = Set(
            sharedEvents.map {
                SharedCloudKitRecordMapper.makeOwnedEventRecordID(for: $0.id, zoneID: ownedZoneID)
            }
        )
        let existingEventRecords: [CKRecord]
        let canDeleteStaleRecords: Bool
        do {
            existingEventRecords = try await fetchOwnedEventRecords()
            canDeleteStaleRecords = true
        } catch {
            existingEventRecords = []
            canDeleteStaleRecords = false
        }
        
        let staleRecordIDs = canDeleteStaleRecords
            ? existingEventRecords
                .map(\.recordID)
                .filter { desiredRecordIDs.contains($0) == false }
            : []
        let eventRecords = sharedEvents
            .map {
                SharedCloudKitRecordMapper.makeOwnedEventRecord(
                    from: $0,
                    calendarRecord: calendarRecord,
                    zoneID: ownedZoneID
                )
            }
        guard eventRecords.isEmpty == false || staleRecordIDs.isEmpty == false else {
            return canDeleteStaleRecords ? .synced : .failed
        }
        
        do {
            let result = try await privateDatabase.modifyRecords(
                saving: eventRecords,
                deleting: staleRecordIDs,
                savePolicy: .allKeys,
                atomically: false
            )
            return eventSyncResult(
                saveResults: Array(result.saveResults.values),
                deleteResults: Array(result.deleteResults.values),
                requestedCount: eventRecords.count + staleRecordIDs.count
            )
        } catch {
            return .failed
        }
    }
    
    private func eventSyncResult(
        saveResults: [Result<CKRecord, Error>],
        deleteResults: [Result<Void, Error>],
        requestedCount: Int
    ) -> CloudSharingEventSyncResult {
        let failureCount = failureCount(in: saveResults) + failureCount(in: deleteResults)
        if failureCount == 0 {
            return .synced
        }
        return failureCount < requestedCount ? .partiallyFailed : .failed
    }
    
    private func failureCount<Success>(in results: [Result<Success, Error>]) -> Int {
        results.filter {
            guard case .failure = $0 else { return false }
            return true
        }.count
    }
    
}
