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
    /// Тип дозировки (капля / таблетка / нажатие)
    var dosageType: DosageType
    /// Количество (1, 2, 3 ...)
    var amount: Int
    var comment: String?

    init(
        date: Date,
        medicationId: String,
        packageId: String,
        dosageType: DosageType,
        amount: Int,
        comment: String?
    ) {
        self.id = UUID()
        self.date = date
        self.medicationId = medicationId
        self.packageId = packageId
        self.dosageType = dosageType
        self.amount = amount
        self.comment = comment
    }
}

enum TherapyType: String, Codable {
    case scit
    case slit
}

enum DosageType: String, Codable {
    case press
    case tablet
}
