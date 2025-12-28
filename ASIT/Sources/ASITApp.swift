//
//  ASITApp.swift
//  ASIT
//
//  Created by Egor Malyshev on 16.12.2025.
//

import SwiftUI
import SwiftData

@main
struct ASITApp: App {
    @StateObject var localizationService = LocalizationService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Course.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(localizationService)
    }
}
