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
                    NavigationLink {
                        SelectionList(
                            title: "Вариант",
                            items: viewModel.availableVariants,
                            selection: $viewModel.selectedVariantId
                        ) {
                            $0.name.ru
                        }
                    } label: {
                        LabeledContent("Вариант") {
                            let variant = viewModel.availableVariants.first(where: { $0.id == viewModel.selectedVariantId })
                            Text(variant?.name.ru ?? "")
                        }
                    }

                    NavigationLink {
                        SelectionList(
                            title: "Дозировка",
                            items: viewModel.availableDosages,
                            selection: Binding(
                                get: { viewModel.selectedDosage?.id },
                                set: { id in
                                    viewModel.selectedDosage = viewModel.availableDosages.first(where: { $0.id == id })
                                }
                            )
                        ) {
                            $0.displayName
                        }
                    } label: {
                        LabeledContent("Дозировка") {
                            Text(viewModel.selectedDosage?.displayName ?? "")
                        }
                    }
                }

                Section {
                    Button(viewModel.isEditing ? "Изменить" : "Добавить") {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)

                    if viewModel.isEditing {
                        Button("Удалить") {
                            viewModel.delete()
                            dismiss()
                        }
                        .foregroundStyle(.red)
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
