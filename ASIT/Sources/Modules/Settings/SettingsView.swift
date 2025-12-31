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
    @State private var selectedTime = Date()
    
    @Environment(\.dismiss) private var dismiss
    
    init(courseService: CourseManagementServiceProtocol) {
        _viewModel = State(initialValue: SettingsViewModel(courseService: courseService))
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

                Button {
                    NotificationService.shared.cancelAllReminders()
                } label: {
                    Text("Отменить все")
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
        }
    }
    
    private func reminderRow(reminder: Reminder, course: Course) -> some View {
        HStack {
            Label(reminder.formattedTime, systemImage: "bell.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(role: .destructive) {
                viewModel.deleteReminder(reminder, from: course)
            } label: {
                Image(systemName: "trash")
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
    SettingsView(courseService: MockCourseManagementService(withMockData: true))
}
