//
//  CourseSettingsView.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import SwiftUI

struct CourseSettingsView: View {
    @State private var viewModel: CourseSettingsViewModel

    init(course: Course, courseService: CourseManagementServiceProtocol) {
        _viewModel = State(initialValue: CourseSettingsViewModel(course: course, courseService: courseService))
    }

    var body: some View {
        Form {
            Picker("Упаковка", selection: $viewModel.selectedPackageId) {
                ForEach(viewModel.availablePackages, id: \.id) { package in
                    Text(package.name.ru)
                        .tag(package.id)
                }
            }

            Picker("Дозировка", selection: $viewModel.selectedDosage) {
                ForEach(viewModel.availableDosages, id: \.amount) { dosage in
                    Text(dosage.displayName)
                        .tag(dosage)
                }
            }

            Button("Добавить уведомление") {}
        }
        .navigationTitle(viewModel.medication?.name.ru ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CourseSettingsView(course: .mock, courseService: MockCourseManagementService())
    }
}
