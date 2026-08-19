//
//  AddCourseView.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import SwiftUI

struct AddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: AddCourseViewModel

    init(courseService: CourseManagementServiceProtocol) {
        _viewModel = State(initialValue: AddCourseViewModel(courseService: courseService))
    }

    var body: some View {
        NavigationStack {
            Form {
                NavigationLink {
                    SelectionList(
                        title: "Препарат",
                        items: viewModel.availableMedications,
                        selection: $viewModel.selectedMedicationId
                    ) {
                        $0.name.ru
                    }
                } label: {
                    LabeledContent("Препарат") {
                        let medication = viewModel.availableMedications.first(where: { $0.id == viewModel.selectedMedicationId })
                        Text(medication?.name.ru ?? "")
                    }
                }

                NavigationLink {
                    SelectionList(
                        title: "Год приёма",
                        items: viewModel.takingYears,
                        selection: $viewModel.selectedYear
                    ) {
                        $0.title
                    }
                } label: {
                    LabeledContent("Год приёма") {
                        let selectedYear = viewModel.takingYears.first(where: { $0.rawValue == viewModel.selectedYear })
                        Text(selectedYear?.title ?? "")
                    }
                }

                DatePicker("Дата начала курса", selection: $viewModel.startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)

                DatePicker("Дата окончания курса", selection: $viewModel.endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            .navigationTitle("Добавить новый курс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        viewModel.addCourse()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .tint(.blue)
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}

#Preview {
    AddCourseView(courseService: CourseManagementService())
}
