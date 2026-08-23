//
//  Reminder.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import SwiftData

@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    /// Час напоминания (0-23)
    var hour: Int
    /// Минута напоминания (0-59)
    var minute: Int
    var isEnabled: Bool

    init(hour: Int, minute: Int, isEnabled: Bool) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }
    
    /// Форматированное время для отображения
    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    /// Date из компонентов времени
    var dateFromComponents: Date? {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date.now)
    }

    static let `default` = Reminder(hour: defaultHour, minute: defaultMinute, isEnabled: false)
    static let defaultHour: Int = 10
    static let defaultMinute: Int = 0
}

