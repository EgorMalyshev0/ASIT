//
//  IntakeSchedule.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import SwiftData

/// Расписание приёма курса: время, на которое запланирован приём, и нужно ли о нём напоминать.
/// Время хранится местное (часы и минуты, без часового пояса) — в поездке приём остаётся в те же
/// «10:00 по местному», а не сдвигается вместе с поясом.
@Model
final class IntakeSchedule {
    @Attribute(.unique) var id: UUID
    /// Час планового приёма (0-23)
    var hour: Int
    /// Минута планового приёма (0-59)
    var minute: Int
    /// Присылать ли уведомление в это время. Само время приёма от флага не зависит
    var isNotificationEnabled: Bool

    init(hour: Int, minute: Int, isNotificationEnabled: Bool) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.isNotificationEnabled = isNotificationEnabled
    }

    /// Форматированное время для отображения
    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Плановый момент приёма в указанный день
    func intakeTime(on date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    static let defaultHour: Int = 10
    static let defaultMinute: Int = 0

    /// Создаёт расписание с дефолтным временем и выключенными уведомлениями
    static func makeDefault() -> IntakeSchedule {
        IntakeSchedule(hour: defaultHour, minute: defaultMinute, isNotificationEnabled: false)
    }
}
