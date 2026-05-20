//
//  ApolloEngineApp.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

@main
struct ApolloEngineApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Subject.self])
        // Local SwiftData store. CloudKit private-database sync is enabled by
        // switching to `.automatic` once the iCloud + CloudKit capability is added.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
