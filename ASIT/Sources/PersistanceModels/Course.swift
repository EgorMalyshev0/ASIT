//
//  Course.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import SwiftData

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    /// ID препарата из JSON-каталога
    var medicationId: String
    var takingYear: MedicationTakingYear
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool
    var isPaused: Bool

    @Relationship(deleteRule: .cascade)
    var intakes: [Intake]

    init(
        medicationId: String,
        takingYear: MedicationTakingYear,
        startDate: Date,
        endDate: Date,
        isCompleted: Bool = false,
        isPaused: Bool = false,
        intakes: [Intake] = []
    ) {
        self.id = UUID()
        self.medicationId = medicationId
        self.takingYear = takingYear
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.isPaused = isPaused
        self.intakes = []
    }
}
