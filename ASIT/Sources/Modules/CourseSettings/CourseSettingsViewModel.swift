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
    let course: Course

    private let courseService: CourseManagementServiceProtocol
    private let medicationService: MedicationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var reminderUpdateTask: Task<Void, Never>?

    init(course: Course, courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.course = course
        self.courseService = courseService
        self.medicationService = medicationService
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

    /// Приём на сегодня уже отмечен — пауза в этом случае начнётся с завтрашнего дня
    var isTodayIntakeDone: Bool {
        course.hasIntake(on: Date())
    }

    /// Ставить паузу и менять даты можно только у идущего курса: не завершённого и не закончившегося
    var isCourseOngoing: Bool {
        let calendar = Calendar.current
        return !course.isCompleted && calendar.startOfDay(for: course.endDate) >= calendar.startOfDay(for: Date())
    }

    func pauseCourse() {
        courseService.pauseCourse(course)
        state.isPaused = course.isPaused
        state.progress = CourseProgress(course: course)
    }

    func resumeCourse() {
        courseService.resumeCourse(course)
        state.isPaused = course.isPaused
        state.progress = CourseProgress(course: course)
    }

    func makeCourseDatesViewModel() -> CourseDatesViewModel {
        CourseDatesViewModel(course: course, courseService: courseService)
    }

    /// Даты курса поменялись — могли удалиться приёмы и обрезаться паузы
    func courseDatesDidChange() {
        state.isPaused = course.isPaused
        state.progress = CourseProgress(course: course)
    }

    func deleteCourse() {
        courseService.deleteCourse(course)
    }

    @MainActor
    private func updateState(for course: Course) {
        let reminder = course.reminders.first ?? Reminder.makeDefault()
        let name = medicationService.medication(withId: course.medicationId)?.name.ru ?? course.medicationId

        let state = CourseSettingsState(
            isReminderEnabled: reminder.isEnabled,
            isPaused: course.isPaused,
            progress: CourseProgress(course: course),
            name: name,
            reminderDate: reminder.dateFromComponents ?? Date()
        )

        self.state = state
    }
}

struct CourseSettingsState {
    var isReminderEnabled: Bool
    var isPaused: Bool
    var progress: CourseProgress
    let name: String
    var reminderDate: Date

    static let empty = CourseSettingsState(isReminderEnabled: false, isPaused: false, progress: .empty, name: "", reminderDate: .distantFuture)
}
