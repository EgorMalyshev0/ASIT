//
//  AppView.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import SwiftUI

struct AppView: View {
    @State private var viewModel: AppViewModel
    @State private var isCourseAddingPresented: Bool = false
    @State private var isCourseSettingsPresented: Bool = false

    private let courseService: CourseManagementServiceProtocol

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        _viewModel = State(initialValue: AppViewModel(courseService: courseService))
    }

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
        if viewModel.hasCourses {
            MainView(courseService: courseService)
        } else {
            MainEmptyView {
                isCourseAddingPresented = true
            }
        }
    }
}

#Preview {
    AppView(courseService: MockCourseManagementService(withMockData: true))
}
