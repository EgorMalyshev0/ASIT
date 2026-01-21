//
//  SettingsView.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var courseForReminder: Course?
    @State private var reminderToEdit: (reminder: Reminder, course: Course)?
    @State private var selectedTime = Date()
    
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
                                Label("Добавить напоминание", systemImage: "bell.badge.plus")
                            }
                        }
                    }
                }

                Button(action: onAddNewCourse) {
                    Text("Добавить новый курс")
                }

//                Button {
//                    NotificationService.shared.cancelAllReminders()
//                } label: {
//                    Text("Отменить все")
//                }

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
