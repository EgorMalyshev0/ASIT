//
//  CourseCalendarRange.swift
//  ASIT
//
//  Created by Egor Malyshev on 12.09.2026.
//

import Foundation

/// Диапазон дат, видимых в календарях приложения (главный, дневной и недельный) —
/// общая логика, чтобы границы скролла везде совпадали.
enum CourseCalendarRange {
    /// Нижняя граница — самая ранняя дата начала среди всех курсов, либо сегодня, если курсов нет
    static func minDate(courses: [Course], calendar: Calendar = .current) -> Date {
        let earliestCourseStart = courses.map(\.startDate).min() ?? Date()
        return calendar.startOfDay(for: earliestCourseStart)
    }

    /// Верхняя граница — конец следующей недели после текущей
    static func maxDate(calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: Date())
        guard let nextWeekEnd = calendar.date(byAdding: .day, value: Constants.visibleFutureDays, to: calendar.mondayWeekStart(for: today)) else {
            return today
        }
        return nextWeekEnd
    }
}

private extension CourseCalendarRange {
    enum Constants {
        static let visibleFutureDays = 13
    }
}
