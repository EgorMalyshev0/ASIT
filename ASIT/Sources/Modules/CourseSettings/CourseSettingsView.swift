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
    @State private var isPauseAlertPresented: Bool = false
    @State private var isDatesEditingPresented: Bool = false

    init(viewModel: CourseSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section {
                CourseProgressView(progress: viewModel.state.progress)
            }

            Section {
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
            } header: {
                Text("Напоминания")
            } footer: {
                if viewModel.state.isPaused {
                    Text("Уведомления не отправляются, пока курс на паузе")
                }
            }
            .disabled(viewModel.state.isPaused)

            courseManagementSection

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

            #if DEBUG
            Section(header: Text("Debug")) {
                DebugReminderScheduleView(course: viewModel.course)
            }
            #endif
        }
        .navigationTitle(viewModel.state.name)
        .animation(.default, value: viewModel.state.isReminderEnabled)
        .animation(.default, value: viewModel.state.isPaused)
        .alert("Приостановить курс?", isPresented: $isPauseAlertPresented) {
            Button("Поставить на паузу") {
                viewModel.pauseCourse()
            }
            Button("Отмена", role: .cancel, action: {})
        } message: {
            Text(pauseAlertMessage)
        }
        .sheet(isPresented: $isDatesEditingPresented) {
            CourseDatesView(viewModel: viewModel.makeCourseDatesViewModel()) {
                viewModel.courseDatesDidChange()
            }
        }
    }

    private var courseManagementSection: some View {
        Section {
            Button {
                isDatesEditingPresented = true
            } label: {
                Label("Изменить даты курса", systemImage: "calendar")
            }

            if viewModel.canChangePause {
                if viewModel.state.isPaused {
                    Button {
                        viewModel.resumeCourse()
                    } label: {
                        Label("Возобновить курс", systemImage: "play.fill")
                    }
                } else {
                    Button {
                        isPauseAlertPresented = true
                    } label: {
                        Label("Приостановить курс", systemImage: "pause.fill")
                    }
                }
            }
        }
    }

    private var pauseAlertMessage: String {
        let description = "Пока курс на паузе, напоминания не приходят, а дни не считаются пропущенными. Отмечать приёмы в эти дни нельзя. Снять паузу можно в любой момент здесь же."
        guard viewModel.isTodayIntakeDone else {
            return description
        }
        return description + "\nПриём на сегодня уже отмечен, поэтому пауза начнётся с завтрашнего дня."
    }
}
