//
//  Calendar+MondayWeekStart.swift
//  ASIT
//
//  Created by Egor Malyshev on 12.09.2026.
//

import Foundation

extension Calendar {
    /// Начало недели (понедельник) для данной даты, независимо от локали устройства.
    /// `yearForWeekOfYear`/`weekOfYear` следуют за `firstWeekday`, который в некоторых
    /// локалях — воскресенье, а вся остальная вёрстка (шапка недели, сетка календарей)
    /// жёстко считает неделю начинающейся с понедельника. Расхождение между ними —
    /// причина того, что переход Вс → Пн не всегда засчитывался как смена недели.
    func mondayWeekStart(for date: Date) -> Date {
        let startOfDay = self.startOfDay(for: date)
        let weekday = component(.weekday, from: startOfDay) // 1 = вс, ..., 7 = сб
        let daysSinceMonday = (weekday + 5) % 7
        return self.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }
}
