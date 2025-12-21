//
//  AddCourseView.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import SwiftData
import SwiftUI

struct AddCourseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: AddCourseViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: AddCourseViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    HStack {
                        Picker("Выберите препарат", selection: $viewModel.selectedMedicationId) {
                            ForEach(viewModel.availableMedications, id: \.id) { medication in
                                Text(medication.name.ru)
                                    .tag(medication.id)
                            }
                        }
                    }

                    HStack {
                        Picker("Выберите год приёма", selection: $viewModel.selectedYear) {
                            ForEach(viewModel.takingYears, id: \.rawValue) { takingYear in
                                Text(takingYear.title)
                                    .tag(takingYear.rawValue)
                            }
                        }
                    }

                    DatePicker("Выберите дату начала курса", selection: $viewModel.startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    DatePicker("Выберите дату окончания курса", selection: $viewModel.endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                .navigationTitle("Добавить новый курс")
                .navigationBarTitleDisplayMode(.inline)
            }
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Course.self, configurations: config)

    AddCourseView(modelContext: container.mainContext)
}
