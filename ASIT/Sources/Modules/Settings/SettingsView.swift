//
//  SettingsView.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var courseForReminder: Course?
    @State private var reminderToEdit: (reminder: Reminder, course: Course)?
    @State private var selectedTime = Date()
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var courseToDelete: Course?
    
    @Environment(\.dismiss) private var dismiss

    let onAddNewCourse: () -> Void

    init(courseService: CourseManagementServiceProtocol, onAddNewCourse: @escaping () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(courseService: courseService))
        self.onAddNewCourse = onAddNewCourse
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.courses) { course in
                    Section(header: Text(viewModel.medicationName(for: course))) {
                        if let reminder = course.reminders.first {
                            reminderRow(reminder: reminder, course: course)
                        } else {
                            Button {
                                courseForReminder = course
                            } label: {
                                Label("Добавить напоминание", systemImage: "bell")
                            }
                        }
                        
                        ShareLink(
                            item: CourseFileExport(course: course),
                            preview: SharePreview(
                                viewModel.medicationName(for: course),
                                image: Image(systemName: "doc.fill")
                            )
                        ) {
                            Label("Экспортировать курс", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            courseToDelete = course
                        } label: {
                            Label("Удалить курс", systemImage: "trash")
                        }
                    }
                }

                Section {
                    Button(action: onAddNewCourse) {
                        Label("Добавить новый курс", systemImage: "plus.circle")
                    }
                    
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Импортировать курс", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $courseForReminder) { course in
                addReminderSheet(for: course)
            }
            .sheet(isPresented: Binding(
                get: { reminderToEdit != nil },
                set: { if !$0 { reminderToEdit = nil } }
            )) {
                if let edit = reminderToEdit {
                    editReminderSheet(reminder: edit.reminder, course: edit.course)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        try viewModel.importCourse(from: url)
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Ошибка импорта", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .confirmationDialog(
                "Удалить курс?",
                isPresented: Binding(
                    get: { courseToDelete != nil },
                    set: { if !$0 { courseToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let course = courseToDelete {
                        viewModel.deleteCourse(course)
                    }
                    courseToDelete = nil
                }
                Button("Отмена", role: .cancel) {
                    courseToDelete = nil
                }
            } message: {
                Text("Все данные курса, включая историю приёмов, будут удалены.")
            }
        }
    }
    
    private func editReminderSheet(reminder: Reminder, course: Course) -> some View {
        NavigationStack {
            DatePicker(
                "Время напоминания",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        reminderToEdit = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        viewModel.updateReminder(
                            reminder,
                            hour: components.hour ?? 9,
                            minute: components.minute ?? 0,
                            in: course
                        )
                        reminderToEdit = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func reminderRow(reminder: Reminder, course: Course) -> some View {
        Button {
            selectedTime = reminder.dateFromComponents ?? Date()
            reminderToEdit = (reminder, course)
        } label: {
            Label(reminder.formattedTime, systemImage: "bell.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.deleteReminder(reminder, from: course)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
    
    private func addReminderSheet(for course: Course) -> some View {
        NavigationStack {
            DatePicker(
                "Время напоминания",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .navigationTitle("Новое напоминание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        courseForReminder = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        viewModel.addReminder(
                            hour: components.hour ?? 9,
                            minute: components.minute ?? 0,
                            to: course
                        )
                        courseForReminder = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView(courseService: MockCourseManagementService(withMockData: true), onAddNewCourse: {})
}
