//
//  CourseExportDTO.swift
//  ASIT
//
//  Created by Egor Malyshev on 22.01.2026.
//

import Foundation

/// DTO для экспорта/импорта курса в JSON
struct CourseExportDTO: Codable {
    let version: Int
    let exportDate: Date
    let course: CourseDTO
    
    static let currentVersion = 1
    
    init(course: Course) {
        self.version = Self.currentVersion
        self.exportDate = Date()
        self.course = CourseDTO(course: course)
    }
}

struct CourseDTO: Codable {
    let medicationId: String
    let takingYear: MedicationTakingYear
    let startDate: Date
    let endDate: Date
    let isCompleted: Bool
    let isPaused: Bool
    let intakes: [IntakeDTO]
    let reminders: [ReminderDTO]
    
    init(course: Course) {
        self.medicationId = course.medicationId
        self.takingYear = course.takingYear
        self.startDate = course.startDate
        self.endDate = course.endDate
        self.isCompleted = course.isCompleted
        self.isPaused = course.isPaused
        self.intakes = course.intakes.map { IntakeDTO(intake: $0) }
        self.reminders = course.reminders.map { ReminderDTO(reminder: $0) }
    }
    
    func toCourse() -> Course {
        let course = Course(
            medicationId: medicationId,
            takingYear: takingYear,
            startDate: startDate,
            endDate: endDate,
            isCompleted: isCompleted,
            isPaused: isPaused
        )
        return course
    }
    
    func createIntakes() -> [Intake] {
        intakes.map { $0.toIntake() }
    }
    
    func createReminders() -> [Reminder] {
        reminders.map { $0.toReminder() }
    }
}

struct IntakeDTO: Codable {
    let date: Date
    let medicationId: String
    let packageId: String
    let dosage: Dosage
    let comment: String?
    
    init(intake: Intake) {
        self.date = intake.date
        self.medicationId = intake.medicationId
        self.packageId = intake.packageId
        self.dosage = intake.dosage
        self.comment = intake.comment
    }
    
    func toIntake() -> Intake {
        Intake(
            date: date,
            medicationId: medicationId,
            packageId: packageId,
            dosage: dosage,
            comment: comment
        )
    }
}

struct ReminderDTO: Codable {
    let hour: Int
    let minute: Int
    
    init(reminder: Reminder) {
        self.hour = reminder.hour
        self.minute = reminder.minute
    }
    
    func toReminder() -> Reminder {
        Reminder(hour: hour, minute: minute)
    }
}

