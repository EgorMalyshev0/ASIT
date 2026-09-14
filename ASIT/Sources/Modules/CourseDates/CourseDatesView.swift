//
//  CourseDatesView.swift
//  ASIT
//
//  Created by Egor Malyshev on 14.09.2026.
//

import SwiftUI

struct CourseDatesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CourseDatesViewModel
    @State private var isConfirmationPresented: Bool = false

    private let onSave: () -> Void

    init(viewModel: CourseDatesViewModel, onSave: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Дата начала курса",
                        selection: $viewModel.startDate,
                        in: viewModel.minStartDate...viewModel.maxStartDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    DatePicker(
                        "Дата окончания курса",
                        selection: $viewModel.endDate,
                        in: viewModel.startDate...viewModel.maxEndDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                } footer: {
                    if viewModel.removedIntakesCount > 0 {
                        Text("Приёмы вне новых дат курса будут удалены")
                    }
                }
            }
            .navigationTitle("Даты курса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarActionButton(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ToolbarActionButton(role: .confirm) {
                        if viewModel.needsConfirmation {
                            isConfirmationPresented = true
                        } else {
                            save()
                        }
                    }
                    .disabled(!viewModel.hasChanges)
                }
            }
            .alert("Изменить даты курса?", isPresented: $isConfirmationPresented) {
                Button("Изменить", role: .destructive) {
                    save()
                }
                Button("Отмена", role: .cancel, action: {})
            } message: {
                Text(confirmationMessage)
            }
        }
    }

    private var intakesCountText: String {
        String(format: NSLocalizedString("intakes.count", comment: ""), viewModel.removedIntakesCount)
    }

    private var confirmationMessage: String {
        var lines: [String] = []
        if viewModel.removedIntakesCount > 0 {
            lines.append("Будут удалены приёмы вне новых дат курса. Это действие нельзя отменить.")
        }
        if viewModel.willFinishCourse {
            lines.append("Дата окончания уже прошла — курс завершится, и менять его даты больше будет нельзя.")
        }
        return lines.joined(separator: "\n")
    }

    private func save() {
        viewModel.save()
        onSave()
        dismiss()
    }
}
