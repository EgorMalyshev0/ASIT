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
        comment: String?
    ) {
        self.id = UUID()
        self.date = date
        self.medicationId = medicationId
        self.variantId = variantId
        self.dosage = dosage
        self.comment = comment
    }
}
