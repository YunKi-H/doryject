//
//  WidgetSnapshotStore.swift
//  BloodyDayWidget
//
//  Created by Yunki on 3/21/26.
//

import Foundation

struct WidgetSnapshotStore {
    static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    
    private let fileName = "widget_snapshot.json"
    private let appGroupIdentifier: String
    
    init(appGroupIdentifier: String = Self.appGroupIdentifier) {
        self.appGroupIdentifier = appGroupIdentifier
    }
    
    func load() -> WidgetSnapshot? {
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
    
    private func storageURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}
