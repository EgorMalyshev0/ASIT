//
//  IntakeTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 16.09.2026.
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct IntakeTests {
    private let calendar = Calendar.current

    private func makeIntake(date: Date) -> Intake {
        Intake(
            date: date,
            medicationId: "staloral_birch_pollen",
            variantId: "staloral_birch_pollen_10_ir_ml",
            dosage: Dosage(type: .press, amount: 1),
            comment: "",
            calendar: calendar
        )
    }

    @Test func date_isNormalizedToStartOfDay() {
        let evening = calendar.date(bySettingHour: 23, minute: 40, second: 0, of: .now)!

        let intake = makeIntake(date: evening)

        #expect(intake.date == calendar.startOfDay(for: evening))
    }

    /// Приём, отмеченный поздно вечером, относится к своему дню, а не уезжает на следующий
    @Test func lateEveningIntake_belongsToItsOwnDay() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        let evening = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: yesterday)!
        let course = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: calendar.date(byAdding: .day, value: -5, to: .now)!,
            endDate: calendar.date(byAdding: .day, value: 5, to: .now)!
        )
        course.intakes = [makeIntake(date: evening)]

        #expect(course.hasIntake(on: yesterday))
        #expect(!course.hasIntake(on: .now))
    }
}
