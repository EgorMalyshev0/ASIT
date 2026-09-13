//
//  CoursePause.swift
//  ASIT
//
//  Created by Egor Malyshev on 13.09.2026.
//

import Foundation
import SwiftData

/// Период паузы курса. Интервал полуоткрытый — [startDate, endDate): дни паузы не считаются
/// пропущенными, в них не приходят уведомления и нельзя отметить приём.
@Model
final class CoursePause {
    @Attribute(.unique) var id: UUID
    /// Первый день паузы (начало дня)
    var startDate: Date
    /// Первый день после паузы (начало дня); nil — пауза ещё не снята
    var endDate: Date?

    init(startDate: Date, endDate: Date? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Попадает ли день в период паузы
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: startDate) else {
            return false
        }
        guard let endDate else {
            return true
        }
        return day < calendar.startOfDay(for: endDate)
    }
}
