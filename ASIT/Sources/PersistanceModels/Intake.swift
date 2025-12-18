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
    /// ID упаковки
    var packageId: String
    /// Дозировка
    var dosage: Dosage
    var comment: String?

    init(
        date: Date,
        medicationId: String,
        packageId: String,
        dosage: Dosage,
        comment: String?
    ) {
        self.id = UUID()
        self.date = date
        self.medicationId = medicationId
        self.packageId = packageId
        self.dosage = dosage
        self.comment = comment
    }
}
