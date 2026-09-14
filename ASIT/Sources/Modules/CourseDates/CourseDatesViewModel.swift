//
//  CourseDatesViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 14.09.2026.
//

import Foundation

@Observable
final class CourseDatesViewModel {
    let minStartDate = CourseDateLimits.minStartDate
    let maxStartDate: Date
    var startDate: Date {
        didSet {
            endDate = min(max(endDate, startDate), maxEndDate)
        }
    }
    var endDate: Date

    var maxEndDate: Date {
        CourseDateLimits.maxEndDate(startDate: startDate)
    }

    var hasChanges: Bool {
        let calendar = Calendar.current
        return !calendar.isDate(startDate, inSameDayAs: course.startDate) ||
               !calendar.isDate(endDate, inSameDayAs: course.endDate)
    }

    /// Сколько приёмов удалится, потому что они окажутся вне новых дат
    var removedIntakesCount: Int {
        course.intakes(outsideOf: startDate, endDate).count
    }

    /// Новая дата окончания уже прошла — курс завершится, и менять его даты больше будет нельзя
    var willFinishCourse: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: endDate) < calendar.startOfDay(for: Date())
    }

    /// Сохранение нужно подтвердить: оно удалит данные или завершит курс
    var needsConfirmation: Bool {
        removedIntakesCount > 0 || willFinishCourse
    }

    private let course: Course
    private let courseService: CourseManagementServiceProtocol

    init(course: Course, courseService: CourseManagementServiceProtocol) {
        self.course = course
        self.courseService = courseService
        maxStartDate = CourseDateLimits.maxStartDate()
        startDate = course.startDate
        endDate = course.endDate
    }

    func save() {
        courseService.updateCourseDates(course, startDate: startDate, endDate: endDate)
    }
}
