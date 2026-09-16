//
//  ScheduledTime.swift
//  ASIT
//
//  Created by Egor Malyshev on 16.09.2026.
//

import Foundation

/// Время внутри суток без часового пояса — на него планируется приём. В поездке приём остаётся
/// в те же «10:00 по местному», а не сдвигается вместе с поясом
struct ScheduledTime: Codable, Hashable, Comparable {
    /// Часы (0-23)
    let hour: Int
    /// Минуты (0-59)
    let minute: Int

    /// Время суток из момента времени
    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Момент этого времени в указанном дне
    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    static func < (lhs: ScheduledTime, rhs: ScheduledTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}
