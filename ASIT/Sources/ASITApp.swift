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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .environmentObject(appDelegate.localizationService)
        .environmentObject(appDelegate.courseService)
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                NotificationService.shared.clearBadge()
            }
        }
    }
}
