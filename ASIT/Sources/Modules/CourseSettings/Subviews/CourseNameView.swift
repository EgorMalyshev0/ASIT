//
//  CourseNameView.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.09.2026.
//

import SwiftUI

/// Отдельный экран для имени курса: на экране курса остаётся только строка со значением.
/// Имя правится локально и уходит в курс только по кнопке сохранения или по submit
struct CourseNameView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: CourseSettingsViewModel

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(viewModel: CourseSettingsViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.state.customName)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Constants.nameAccessorySpacing) {
                    TextField(viewModel.state.medicationName, text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .onChange(of: name) { _, newName in
                            trimToLimit(newName)
                        }

                    if let remainingCount {
                        Text("\(remainingCount)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Осталось символов: \(remainingCount)")
                    }

                    if !name.isEmpty {
                        Button {
                            name = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .tint(.secondary)
                        .accessibilityLabel("Очистить название")
                    }
                }
            } footer: {
                Text("Вы можете задать своё название для курса. Если оставить поле пустым, вместо него будет отображаться наименование препарата")
            }
        }
        .navigationTitle("Название курса")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                ToolbarActionButton(role: .confirm, action: save)
            }
        }
        .task {
            // Фокус ставим не в onAppear: пока идёт анимация пуша, SwiftUI сбрасывает FocusState,
            // и клавиатура не открывается
            try? await Task.sleep(for: .milliseconds(Constants.focusDelayMilliseconds))
            isNameFocused = true
        }
    }

    /// Сколько символов имени осталось до лимита
    private var remainingCount: Int? {
        let remainingCount = Constants.nameMaxLength - name.count
        return remainingCount <= Constants.nameMinRemainingCount ? remainingCount : nil
    }

    private func save() {
        viewModel.saveCustomName(name)
        dismiss()
    }

    /// Обрезает имя до лимита. Вызывается из onChange, а не из сеттера: там обрезанное значение
    /// совпадает с уже сохранённым, изменения состояния нет, и TextField оставляет у себя набранный текст
    private func trimToLimit(_ newName: String) {
        guard newName.count > Constants.nameMaxLength else {
            return
        }

        name = String(newName.prefix(Constants.nameMaxLength))
    }
}

extension CourseNameView {
    private enum Constants {
        static let nameMaxLength = 40
        static let nameMinRemainingCount = 10
        static let nameAccessorySpacing: CGFloat = 8
        static let focusDelayMilliseconds = 300
    }
}
