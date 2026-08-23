//
//  CourseSettingsViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 22.08.2026.
//

import Combine
import Foundation

@Observable
final class CourseSettingsViewModel {
    var state: CourseSettingsState = .empty
    var medications: [Medication] = []
    let course: Course

    private let courseService: CourseManagementServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var reminderUpdateTask: Task<Void, Never>?

    init(course: Course, courseService: CourseManagementServiceProtocol) {
        self.course = course
        self.courseService = courseService
        fetchMedications()
        updateState(for: course)
    }

    func setReminderEnabled(_ isEnabled: Bool) {
        state.isReminderEnabled = isEnabled
        courseService.setReminderEnabled(isEnabled, course: course)
    }

    func updateReminderTime(_ newTime: Date) {
        state.reminderDate = newTime
        reminderUpdateTask?.cancel()

        reminderUpdateTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }

            guard let self else {
                return
            }

            courseService.updateReminderTime(newTime, course: course)
        }
    }

    func deleteCourse() {
        courseService.deleteCourse(course)
    }

    @MainActor
    private func updateState(for course: Course) {
        let reminder = course.reminders.first ?? Reminder.default
        let name = medications.first { $0.id == course.medicationId }?.name.ru ?? course.medicationId

        let state = CourseSettingsState(
            isReminderEnabled: reminder.isEnabled,
            name: name,
            reminderDate: reminder.dateFromComponents ?? Date()
        )

        self.state = state
    }

    private func fetchMedications() {
        guard let url = Bundle.main.url(forResource: "Medications", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            medications = try decoder.decode([Medication].self, from: data)
        } catch {
            print("Failed to decode Medications: \(error)")
        }
    }
}

struct CourseSettingsState {
    var isReminderEnabled: Bool
    let name: String
    var reminderDate: Date

    static let empty = CourseSettingsState(isReminderEnabled: false, name: "", reminderDate: .distantFuture)
}
