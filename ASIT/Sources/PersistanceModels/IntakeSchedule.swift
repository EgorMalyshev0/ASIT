//
//  IntakeSchedule.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import SwiftData

/// Расписание приёма курса: время, на которое запланирован приём, и нужно ли о нём напоминать.
/// Когда приёмов в дне станет несколько, каждый будет отдельной строкой расписания
@Model
final class IntakeSchedule {
    @Attribute(.unique) var id: UUID
    /// Время планового приёма
    var time: ScheduledTime
    /// Присылать ли уведомление в это время. Само время приёма от флага не зависит
    var isNotificationEnabled: Bool

    init(time: ScheduledTime, isNotificationEnabled: Bool) {
        self.id = UUID()
        self.time = time
        self.isNotificationEnabled = isNotificationEnabled
    }

    /// Форматированное время для отображения
    var formattedTime: String {
        time.formatted
    }

    /// Плановый момент приёма в указанный день
    func intakeTime(on date: Date, calendar: Calendar = .current) -> Date? {
        time.date(on: date, calendar: calendar)
    }

    static let defaultTime = ScheduledTime(hour: 10, minute: 0)

    /// Создаёт расписание с дефолтным временем и выключенными уведомлениями
    static func makeDefault() -> IntakeSchedule {
        IntakeSchedule(time: defaultTime, isNotificationEnabled: false)
    }
}

extension IntakeSchedule {
    convenience init(hour: Int, minute: Int, isNotificationEnabled: Bool) {
        self.init(time: ScheduledTime(hour: hour, minute: minute), isNotificationEnabled: isNotificationEnabled)
    }
}
