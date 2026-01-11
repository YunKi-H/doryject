//
//  UserDefaultsAppleCalendarSyncStore.swift
//  BloodyDay
//
//  Created by Yunki on 1/10/26.
//

import Foundation

final class UserDefaultsAppleCalendarSyncStore: AppleCalendarSyncStore {
    private let key = "apple.calendar.sync.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        defaults.removeObject(forKey: key)
    }

    private func loadAll() -> [String: AppleCalendarSyncRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([String: AppleCalendarSyncRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    private func saveAll(_ records: [String: AppleCalendarSyncRecord]) {
        let data = try? JSONEncoder().encode(records)
        defaults.set(data, forKey: key)
    }
}
