//
//  Intake.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import SwiftData

@Model
final class Intake {
    @Attribute(.unique) var id: UUID
    /// День курса, к которому относится приём (начало дня). Хранится отдельно от фактического
    /// времени: приём, отмеченный ночью, всё равно относится к своему дню курса
    var date: Date
    /// Фактический момент приёма; nil — приём отмечен задним числом и точное время неизвестно
    var takenAt: Date?
    /// ID препарата (снапшот)
    var medicationId: String
    /// ID варианта препарата
    var variantId: String
    /// Дозировка
    var dosage: Dosage
    var comment: String?

    init(
        date: Date,
        takenAt: Date? = nil,
        medicationId: String,
        variantId: String,
        dosage: Dosage,
        comment: String?,
        calendar: Calendar = .current
    ) {
        self.id = UUID()
        self.date = calendar.startOfDay(for: date)
        self.takenAt = takenAt
        self.medicationId = medicationId
        self.variantId = variantId
        self.dosage = dosage
        self.comment = comment
    }

    /// Отметка приёма за указанный день. Фактическое время известно только для сегодняшнего дня —
    /// за прошлые дни пользователь отмечает приём постфактум
    static func makeTaken(
        on date: Date,
        medicationId: String,
        variantId: String,
        dosage: Dosage,
        comment: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Intake {
        Intake(
            date: date,
            takenAt: calendar.isDate(date, inSameDayAs: now) ? now : nil,
            medicationId: medicationId,
            variantId: variantId,
            dosage: dosage,
            comment: comment,
            calendar: calendar
        )
    }
}
