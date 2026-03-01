//
//  MindsortappApp.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

@main
struct MindsortappApp: App {
    @State private var store = AppStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CategoryModel.self,
            EntryModel.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(sharedModelContainer)
    }
}
