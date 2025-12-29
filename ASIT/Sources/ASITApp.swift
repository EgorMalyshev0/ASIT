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
    @StateObject private var localizationService = LocalizationService()
    @StateObject private var courseService = CourseManagementService()

    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .environmentObject(localizationService)
        .environmentObject(courseService)
    }
}
