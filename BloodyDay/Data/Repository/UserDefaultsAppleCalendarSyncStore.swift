//
//  UserDefaultsAppleCalendarSyncStore.swift
//  BloodyDay
//
//  Created by Yunki on 1/10/26.
//

import Foundation

final class UserDefaultsAppleCalendarSyncStore: AppleCalendarSyncStore {
    private static let key = "apple.calendar.sync.v1"
    private static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) {
            self.defaults = sharedDefaults
            migrateLegacyValueIfNeeded(to: sharedDefaults)
        } else {
            self.defaults = .standard
        }
    }
    
    func record(for eventId: UUID) -> AppleCalendarSyncRecord? {
        loadAll()[eventId.uuidString]
    }
    
    func records() -> [AppleCalendarSyncRecord] {
        Array(loadAll().values)
    }
    
    func upsert(_ record: AppleCalendarSyncRecord) {
        var all = loadAll()
        all[record.userEventId.uuidString] = record
        saveAll(all)
    }
    
    func remove(for eventId: UUID) {
        var all = loadAll()
        all.removeValue(forKey: eventId.uuidString)
        saveAll(all)
    }
    
    func removeAll() {
        defaults.removeObject(forKey: Self.key)
    }
    
    private func loadAll() -> [String: AppleCalendarSyncRecord] {
        guard let data = defaults.data(forKey: Self.key),
              let records = try? JSONDecoder().decode([String: AppleCalendarSyncRecord].self, from: data) else {
            return [:]
        }
        return records
    }
    
    private func saveAll(_ records: [String: AppleCalendarSyncRecord]) {
        let data = try? JSONEncoder().encode(records)
        defaults.set(data, forKey: Self.key)
    }

    private func migrateLegacyValueIfNeeded(to sharedDefaults: UserDefaults) {
        guard let legacyData = UserDefaults.standard.data(forKey: Self.key),
              let legacyRecords = try? JSONDecoder().decode(
                [String: AppleCalendarSyncRecord].self,
                from: legacyData
              ) else {
            return
        }

        let sharedRecords: [String: AppleCalendarSyncRecord]
        if let sharedData = sharedDefaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(
            [String: AppleCalendarSyncRecord].self,
            from: sharedData
           ) {
            sharedRecords = decoded
        } else {
            sharedRecords = [:]
        }

        let mergedRecords = legacyRecords.merging(sharedRecords) { _, shared in
            shared
        }
        if let mergedData = try? JSONEncoder().encode(mergedRecords) {
            sharedDefaults.set(mergedData, forKey: Self.key)
        }
        sharedDefaults.synchronize()
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
