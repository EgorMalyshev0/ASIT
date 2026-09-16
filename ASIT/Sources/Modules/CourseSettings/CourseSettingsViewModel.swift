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
    private var intakeTimeUpdateTask: Task<Void, Never>?

    init(course: Course, courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.course = course
        self.courseService = courseService
        self.medicationService = medicationService
        updateState(for: course)
    }

    func setNotificationsEnabled(_ isNotificationEnabled: Bool) {
        state.isNotificationEnabled = isNotificationEnabled
        courseService.setNotificationsEnabled(isNotificationEnabled, course: course)
    }

    func updateIntakeTime(_ newTime: Date) {
        state.intakeTime = newTime
        intakeTimeUpdateTask?.cancel()

        intakeTimeUpdateTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }

            guard let self else {
                return
            }

            courseService.updateIntakeTime(newTime, course: course)
        }
    }

    /// Приём на сегодня уже отмечен — пауза в этом случае начнётся с завтрашнего дня
    var isTodayIntakeDone: Bool {
        course.hasIntake(on: Date())
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
        refreshCourseStatus()
    }

    /// Наступил новый день — курс мог завершиться, а прогресс сдвинуться
    func dayDidChange() {
        refreshCourseStatus()
    }

    func deleteCourse() {
        courseService.deleteCourse(course)
    }

    private func refreshCourseStatus() {
        state.isPaused = course.isPaused
        state.isCompleted = course.isCompleted
        state.progress = CourseProgress(course: course)
    }

    @MainActor
    private func updateState(for course: Course) {
        let schedule = course.schedules.first ?? IntakeSchedule.makeDefault()
        let name = medicationService.medication(withId: course.medicationId)?.name.ru ?? course.medicationId

        let state = CourseSettingsState(
            isNotificationEnabled: schedule.isNotificationEnabled,
            isPaused: course.isPaused,
            isCompleted: course.isCompleted,
            progress: CourseProgress(course: course),
            name: name,
            intakeTime: schedule.intakeTime(on: Date()) ?? Date()
        )

        self.state = state
    }
}

struct CourseSettingsState {
    var isNotificationEnabled: Bool
    var isPaused: Bool
    var isCompleted: Bool
    var progress: CourseProgress
    let name: String
    var intakeTime: Date

    static let empty = CourseSettingsState(isNotificationEnabled: false, isPaused: false, isCompleted: false, progress: .empty, name: "", intakeTime: .distantFuture)
}
