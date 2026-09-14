//
//  CourseDateLimits.swift
//  ASIT
//
//  Created by Egor Malyshev on 14.09.2026.
//

import Foundation

/// Ограничения на даты курса — общие для создания курса и корректировки его дат
enum CourseDateLimits {
    /// Максимальная длительность курса
    static let maxCourseDuration = DateComponents(year: 1, month: 1)
    /// Насколько вперёд от сегодняшнего дня можно назначить начало курса
    static let maxStartDateOffset = DateComponents(month: 1)
    static let minStartDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast

    static func maxStartDate(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: maxStartDateOffset, to: .now) ?? .now
    }

    static func maxEndDate(startDate: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: maxCourseDuration, to: startDate) ?? startDate
    }
}
