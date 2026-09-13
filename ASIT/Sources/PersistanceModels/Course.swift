//
//  Course.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import SwiftData

@Model
final class Course: Sendable {
    @Attribute(.unique) var id: UUID
    /// ID препарата из JSON-каталога
    var medicationId: String
    var takingYear: MedicationTakingYear
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool

    @Relationship(deleteRule: .cascade)
    var intakes: [Intake]
    
    @Relationship(deleteRule: .cascade)
    var reminders: [Reminder]

    @Relationship(deleteRule: .cascade)
    var pauses: [CoursePause]

    init(
        medicationId: String,
        takingYear: MedicationTakingYear,
        startDate: Date,
        endDate: Date,
        isCompleted: Bool = false,
        intakes: [Intake] = [],
        reminders: [Reminder] = []
    ) {
        self.id = UUID()
        self.medicationId = medicationId
        self.takingYear = takingYear
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.intakes = []
        self.reminders = []
        self.pauses = []
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

    /// Текущая (ещё не снятая) пауза — может начинаться и с завтрашнего дня
    var activePause: CoursePause? {
        pauses.first { $0.endDate == nil }
    }

    /// Стоит ли курс на паузе (есть не снятая пауза)
    var isPaused: Bool {
        activePause != nil
    }

    /// Попадает ли день в один из периодов паузы
    func isPaused(on date: Date) -> Bool {
        pauses.contains { $0.contains(date) }
    }

    /// Идёт ли курс в указанный день (без учёта пауз)
    func isActive(on date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return !isCompleted &&
               day >= calendar.startOfDay(for: startDate) &&
               day <= calendar.startOfDay(for: endDate)
    }

    /// Можно ли отметить приём на указанный день: не в будущем и не на паузе
    func canAddIntake(on date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: Date()) && !isPaused(on: date)
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
