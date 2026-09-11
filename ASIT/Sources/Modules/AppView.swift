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
    private let medicationService: MedicationServiceProtocol

    init(courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.courseService = courseService
        self.medicationService = medicationService
        _viewModel = State(initialValue: AppViewModel(courseService: courseService))
    }

    var body: some View {
        content
            .sheet(isPresented: $isCourseAddingPresented) {
                AddCourseView(courseService: courseService, medicationService: medicationService)
            }
    }
}

private extension AppView {
    @ViewBuilder
    var content: some View {
        if viewModel.hasCourses {
            MainView(courseService: courseService, medicationService: medicationService)
        } else {
            MainEmptyView {
                isCourseAddingPresented = true
            }
        }
    }
}

#Preview {
    AppView(courseService: MockCourseManagementService(withMockData: true), medicationService: MockMedicationService())
}
