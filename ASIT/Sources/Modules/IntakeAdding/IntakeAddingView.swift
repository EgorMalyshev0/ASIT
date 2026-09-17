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
    @FocusState private var isCommentFocused: Bool

    init(course: Course, date: Date, courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        _viewModel = State(initialValue: IntakeAddingViewModel(course: course, date: date, courseService: courseService, medicationService: medicationService))
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

                Section("Комментарий") {
                    HStack(alignment: .top) {
                        TextField("Опишите своё самочувствие", text: $viewModel.comment, axis: .vertical)
                            .lineLimit(Constants.commentLineLimit, reservesSpace: true)
                            .focused($isCommentFocused)
                            .onChange(of: viewModel.comment) { _, _ in
                                viewModel.trimCommentToLimit()
                            }

                        if !viewModel.comment.isEmpty {
                            VStack {
                                Button {
                                    viewModel.comment = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .tint(.secondary)
                                .accessibilityLabel("Очистить комментарий")

                                Spacer()

                                if let commentRemainingCount = viewModel.commentRemainingCount {
                                    Text("\(commentRemainingCount)")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Осталось символов: \(commentRemainingCount)")
                                }
                            }
                        }
                    }
                }

                if viewModel.isEditing {
                    Section {
                        Button("Удалить приём") {
                            viewModel.delete()
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(viewModel.isEditing ? "Изменить приём" : "Добавить приём")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarActionButton(role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    ToolbarActionButton(role: .confirm) {
                        viewModel.save()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Готово") {
                        isCommentFocused = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

extension IntakeAddingView {
    private enum Constants {
        static let commentLineLimit = 3
        static let commentAccessorySpacing: CGFloat = 4
    }
}

#Preview {
    IntakeAddingView(course: .mock, date: .now, courseService: MockCourseManagementService(), medicationService: MockMedicationService())
}
