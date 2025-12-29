//
//  AppView.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import SwiftUI

struct AppView: View {
    @EnvironmentObject private var courseService: CourseManagementService
    @State private var isCourseAddingPresented: Bool = false
    @State private var isCourseSettingsPresented: Bool = false

    var body: some View {
        content
            .sheet(isPresented: $isCourseAddingPresented) {
                AddCourseView(courseService: courseService)
            }
    }
}

private extension AppView {
    @ViewBuilder
    var content: some View {
        if courseService.courses.isEmpty {
            MainEmptyView {
                isCourseAddingPresented = true
            }
        } else {
            MainView(courseService: courseService)
        }
    }
}

#Preview {
    AppView()
        .environmentObject(CourseManagementService())
}
