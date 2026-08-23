//
//  CourseSettingsView.swift
//  ASIT
//
//  Created by Egor Malyshev on 21.08.2026.
//

import SwiftUI

struct CourseSettingsView: View {
    let viewModel: CourseSettingsViewModel

    @State private var areNotificationsEnabled: Bool = true
    @State private var isDeleteAlertPresented: Bool = false

    init(viewModel: CourseSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section(header: Text("Напоминания")) {
                Toggle("Отправлять ежедневное уведомление",
                       isOn: Binding(
                        get: { viewModel.state.isReminderEnabled },
                        set: { viewModel.setReminderEnabled($0) }
                       )
                )

                if viewModel.state.isReminderEnabled {
                    DatePicker("Время", selection: Binding(get: { viewModel.state.reminderDate },
                                                           set: { viewModel.updateReminderTime($0) }),
                               displayedComponents: .hourAndMinute)
                }
            }

            Section {
                ShareLink(
                    item: CourseFileExport(course: viewModel.course),
                    preview: SharePreview(
                        viewModel.state.name,
                        image: Image(systemName: "doc.fill")
                    )
                ) {
                    Label("Экспортировать курс", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive) {
                    isDeleteAlertPresented = true
                } label: {
                    Label("Удалить курс", systemImage: "trash")
                }
                .foregroundStyle(.red)
                .confirmationDialog(
                    "Удалить курс?",
                    isPresented: Binding(
                        get: { isDeleteAlertPresented },
                        set: { if !$0 { isDeleteAlertPresented = false } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Удалить", role: .destructive) {
                        viewModel.deleteCourse()
                    }
                    Button("Отмена", role: .cancel, action: {})
                } message: {
                    Text("Все данные курса, включая историю приёмов, будут удалены.")
                }
            }
        }
        .navigationTitle(viewModel.state.name)
        .animation(.default, value: viewModel.state.isReminderEnabled)
    }
}
