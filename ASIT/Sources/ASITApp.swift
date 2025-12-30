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
    @StateObject private var localizationService = LocalizationService()
    @StateObject private var courseService = CourseManagementService()

    var body: some Scene {
        WindowGroup {
            AppView()
                .task {
                    appDelegate.courseService = courseService
                    await NotificationService.shared.requestAuthorization()
                    await NotificationService.shared.syncNotifications(with: courseService.courses)
                }
        }
        .environmentObject(localizationService)
        .environmentObject(courseService)
    }
}
