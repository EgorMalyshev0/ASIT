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
    let intakes: [IntakeDTO]
    let schedules: [IntakeScheduleDTO]
    let pauses: [CoursePauseDTO]
    
    init(course: Course) {
        self.medicationId = course.medicationId
        self.takingYear = course.takingYear
        self.startDate = course.startDate
        self.endDate = course.endDate
        self.intakes = course.intakes.map { IntakeDTO(intake: $0) }
        self.schedules = course.schedules.map { IntakeScheduleDTO(schedule: $0) }
        self.pauses = course.pauses.map { CoursePauseDTO(pause: $0) }
    }
    
    func toCourse() -> Course {
        let course = Course(
            medicationId: medicationId,
            takingYear: takingYear,
            startDate: startDate,
            endDate: endDate
        )
        return course
    }
    
    func createIntakes() -> [Intake] {
        intakes.map { $0.toIntake() }
    }
    
    func createSchedules() -> [IntakeSchedule] {
        schedules.map { $0.toSchedule() }
    }

    func createPauses() -> [CoursePause] {
        pauses.map { $0.toPause() }
    }
}

struct IntakeDTO: Codable {
    /// День курса, за который подтверждён приём
    let date: Date
    let medicationId: String
    let variantId: String
    let dosage: Dosage
    let comment: String?
    
    init(intake: Intake) {
        self.date = intake.date
        self.medicationId = intake.medicationId
        self.variantId = intake.variantId
        self.dosage = intake.dosage
        self.comment = intake.comment
    }
    
    func toIntake() -> Intake {
        Intake(
            date: date,
            medicationId: medicationId,
            variantId: variantId,
            dosage: dosage,
            comment: comment
        )
    }
}

struct IntakeScheduleDTO: Codable {
    let time: ScheduledTime
    let isNotificationEnabled: Bool

    init(schedule: IntakeSchedule) {
        self.time = schedule.time
        self.isNotificationEnabled = schedule.isNotificationEnabled
    }
    
    func toSchedule() -> IntakeSchedule {
        IntakeSchedule(time: time, isNotificationEnabled: isNotificationEnabled)
    }
}

struct CoursePauseDTO: Codable {
    let startDate: Date
    let endDate: Date?

    init(pause: CoursePause) {
        self.startDate = pause.startDate
        self.endDate = pause.endDate
    }

    func toPause() -> CoursePause {
        CoursePause(startDate: startDate, endDate: endDate)
    }
}
