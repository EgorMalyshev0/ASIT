//
//  FullCalendarViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 11.09.2026.
//

import Foundation

@Observable
final class FullCalendarViewModel {
    private let calendar = Calendar.current
    private let courseService: CourseManagementServiceProtocol

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
    }

    // MARK: - Public Methods

    /// Максимальная дата — конец следующей недели после текущей
    var maxDate: Date {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let nextWeekEnd = calendar.date(byAdding: .day, value: Constants.visibleFutureDays, to: weekStart) else {
            return today
        }
        return nextWeekEnd
    }

    /// Генерирует месяцы для отображения (от начала самого раннего курса до maxDate)
    var months: [Date] {
        let earliestCourseStart = courseService.courses.map { $0.startDate }.min() ?? Date()
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliestCourseStart)) ?? earliestCourseStart
        let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: maxDate)) ?? maxDate

        var months: [Date] = []
        var current = startMonth

        while current <= endMonth {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            current = next
        }

        return months
    }

    /// Все дни месяца с padding для выравнивания по дням недели
    func daysInMonth(for month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    func allCoursesHaveIntake(on date: Date) -> Bool {
        let courses = activeCourses(for: date)
        guard !courses.isEmpty else {
            return false
        }
        return courses.allSatisfy { $0.hasIntake(on: date) }
    }

    // MARK: - Private Methods

    private func activeCourses(for date: Date) -> [Course] {
        let startOfDate = calendar.startOfDay(for: date)
        return courseService.courses.filter { course in
            let startOfCourseStart = calendar.startOfDay(for: course.startDate)
            let startOfCourseEnd = calendar.startOfDay(for: course.endDate)

            return startOfDate >= startOfCourseStart &&
                   startOfDate <= startOfCourseEnd &&
                   !course.isCompleted &&
                   !course.isPaused
        }
    }
}

// MARK: - Constants

private extension FullCalendarViewModel {
    enum Constants {
        static let visibleFutureDays = 13
    }
}
