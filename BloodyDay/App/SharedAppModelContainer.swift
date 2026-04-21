//
//  SharedAppModelContainer.swift
//  BloodyDay
//
//  Created by Yunki on 3/21/26.
//

import Foundation
import SwiftData

enum SharedAppModelContainer {
    static let appGroupIdentifier = "group.dorypawn.BDay.shared"
    private static let storeFileName = "BloodyDay.sqlite"
    
    static func make() -> ModelContainer {
        let schema = Schema([UserEvent.self])
        let configuration = ModelConfiguration(
            url: storeURL(),
            cloudKitDatabase: .none
        )
        do {
            let sharedContainer = try ModelContainer(for: schema, configurations: configuration)
            migrateLegacyEventsIfNeeded(into: sharedContainer, schema: schema)
            return sharedContainer
        } catch {
            fatalError("Failed to create shared model container: \(error)")
        }
    }
    
    private static func storeURL() -> URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return groupURL.appendingPathComponent(storeFileName)
        }
        
        let fallbackDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(
            at: fallbackDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return fallbackDirectory.appendingPathComponent(storeFileName)
    }
    
    private static func migrateLegacyEventsIfNeeded(into sharedContainer: ModelContainer, schema: Schema) {
        let sharedContext = ModelContext(sharedContainer)
        let descriptor = FetchDescriptor<UserEvent>()
        
        let sharedEvents = (try? sharedContext.fetch(descriptor)) ?? []
        guard sharedEvents.isEmpty else { return }
        
        let legacyConfiguration = ModelConfiguration(cloudKitDatabase: .none)
        guard let legacyContainer = try? ModelContainer(for: schema, configurations: legacyConfiguration) else { return }
        let legacyContext = ModelContext(legacyContainer)
        let legacyEvents = (try? legacyContext.fetch(descriptor)) ?? []
        guard legacyEvents.isEmpty == false else { return }
        
        for event in legacyEvents {
            sharedContext.insert(
                UserEvent(
                    id: event.id,
                    date: event.date,
                    type: event.type
                )
            )
        }
        
        guard (try? sharedContext.save()) != nil else { return }
        
        for event in legacyEvents {
            legacyContext.delete(event)
        }
        try? legacyContext.save()
    }
}
