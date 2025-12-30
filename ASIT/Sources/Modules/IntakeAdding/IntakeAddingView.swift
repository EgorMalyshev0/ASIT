//
//  IntakeAddingView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

struct IntakeAddingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: IntakeAddingViewModel

    init(course: Course, date: Date, courseService: CourseManagementServiceProtocol) {
        _viewModel = State(initialValue: IntakeAddingViewModel(course: course, date: date, courseService: courseService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(viewModel.medication?.name.ru ?? "") {
                    Picker("Упаковка", selection: $viewModel.selectedPackageId) {
                        ForEach(viewModel.availablePackages, id: \.id) { package in
                            Text(package.name.ru)
                                .tag(package.id as String?)
                        }
                    }

                    Picker("Дозировка", selection: $viewModel.selectedDosage) {
                        ForEach(viewModel.availableDosages, id: \.self) { dosage in
                            Text(dosage.displayName)
                                .tag(dosage as Dosage?)
                        }
                    }
                }

                Section {
                    Button {
                        viewModel.save()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text(viewModel.isEditing ? "Изменить" : "Добавить")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canSave)

                    if viewModel.isEditing {
                        Button {
                            viewModel.delete()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Удалить")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .tint(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Изменить приём" : "Добавить приём")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    IntakeAddingView(course: .mock, date: .now, courseService: MockCourseManagementService())
}
