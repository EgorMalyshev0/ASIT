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
    private var cancellables = Set<AnyCancellable>()
    private var intakeTimeUpdateTask: Task<Void, Never>?

    init(course: Course, courseService: CourseManagementServiceProtocol) {
        self.course = course
        self.courseService = courseService
        updateState(for: course)
    }

    func setNotificationsEnabled(_ isNotificationEnabled: Bool) {
        state.isNotificationEnabled = isNotificationEnabled
        courseService.setNotificationsEnabled(isNotificationEnabled, course: course)
    }

    /// Сохраняет имя курса, заданное пользователем. Пустое имя (в том числе из одних пробелов)
    /// возвращает курсу название препарата
    func saveCustomName(_ newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.customName = trimmedName
        courseService.updateCustomName(trimmedName, course: course)
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

        let state = CourseSettingsState(
            isNotificationEnabled: schedule.isNotificationEnabled,
            isPaused: course.isPaused,
            isCompleted: course.isCompleted,
            progress: CourseProgress(course: course),
            customName: course.customName,
            medicationName: courseService.medicationName(for: course),
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
    /// Имя, заданное пользователем — пустое, пока курс идёт под названием препарата
    var customName: String
    let medicationName: String
    var intakeTime: Date

    /// Имя курса на экране: заданное пользователем, иначе — название препарата
    var name: String {
        customName.isEmpty ? medicationName : customName
    }

    static let empty = CourseSettingsState(isNotificationEnabled: false, isPaused: false, isCompleted: false, progress: .empty, customName: "", medicationName: "", intakeTime: .distantFuture)
}
