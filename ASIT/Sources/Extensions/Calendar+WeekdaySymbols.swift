//
//  Calendar+.swift
//  ASIT
//
//  Created by Egor Malyshev on 11.09.2026.
//

import Foundation

extension Calendar {
    /// Короткие символы дней недели в порядке Пн...Вс.
    /// `shortWeekdaySymbols` в Foundation всегда возвращает их в порядке Вс...Сб
    /// (по номеру компонента weekday), независимо от локали, а неделя в
    /// приложении везде отображается начиная с понедельника.
    var mondayFirstShortWeekdaySymbols: [String] {
        var symbols = shortWeekdaySymbols
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }
}
