//
//  Intake.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import SwiftData

/// Подтверждение приёма. Факт приёма привязан к плановому дню курса, а не к моменту отметки:
/// отмеченный приём считается состоявшимся независимо от того, когда пользователь его подтвердил
@Model
final class Intake {
    @Attribute(.unique) var id: UUID
    /// День курса, за который подтверждён приём (начало дня)
    var date: Date
    /// ID препарата (снапшот)
    var medicationId: String
    /// ID варианта препарата
    var variantId: String
    /// Дозировка
    var dosage: Dosage
    var comment: String?

    init(
        date: Date,
        medicationId: String,
        variantId: String,
        dosage: Dosage,
        comment: String?,
        calendar: Calendar = .current
    ) {
        self.id = UUID()
        self.date = calendar.startOfDay(for: date)
        self.medicationId = medicationId
        self.variantId = variantId
        self.dosage = dosage
        self.comment = comment
    }
}
