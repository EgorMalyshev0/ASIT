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
    
    /// Проверяет, есть ли подтверждённый приём на указанную дату
    func hasIntake(on date: Date) -> Bool {
        let calendar = Calendar.current
        return intakes.contains { intake in
            calendar.isDate(intake.date, inSameDayAs: date)
        }
    }
    
    /// Возвращает приём на указанную дату (если есть)
    func intake(on date: Date) -> Intake? {
        let calendar = Calendar.current
        return intakes.first { intake in
            calendar.isDate(intake.date, inSameDayAs: date)
        }
    }
    
    /// Последний приём (по дате)
    var lastIntake: Intake? {
        intakes.sorted { $0.date > $1.date }.first
    }
}

extension Course {
    static let mock: Course = Course(
        medicationId: "staloral_birch_pollen",
        takingYear: .second,
        startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
        endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    )
}
