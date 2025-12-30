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
    
    init(hour: Int, minute: Int) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
    }
    
    /// Форматированное время для отображения
    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

