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
                Picker("Выберите препарат", selection: $viewModel.selectedMedicationId) {
                    ForEach(viewModel.availableMedications, id: \.id) { medication in
                        Text(medication.name.ru)
                            .tag(medication.id)
                    }
                }

                Picker("Выберите год приёма", selection: $viewModel.selectedYear) {
                    ForEach(viewModel.takingYears, id: \.rawValue) { takingYear in
                        Text(takingYear.title)
                            .tag(takingYear.rawValue)
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
