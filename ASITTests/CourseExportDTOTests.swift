//
//  CourseExportDTOTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 16.09.2026.
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct CourseExportDTOTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    private func makeCourse() -> Course {
        let course = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .second,
            startDate: day(-5),
            endDate: day(5)
        )
        course.schedules = [
            IntakeSchedule(hour: 9, minute: 5, isNotificationEnabled: true),
            IntakeSchedule(hour: 21, minute: 0, isNotificationEnabled: false)
        ]
        course.intakes = [
            Intake(
                date: day(-3),
                medicationId: course.medicationId,
                variantId: "staloral_birch_pollen_10_ir_ml",
                dosage: Dosage(type: .press, amount: 2),
                comment: "первый день"
            )
        ]
        course.pauses = [CoursePause(startDate: day(-2), endDate: day(-1))]
        course.customName = "Берёза, второй год"
        return course
    }

    private func encodedAndDecoded(_ course: Course) throws -> CourseExportDTO {
        let data = try JSONEncoder().encode(CourseExportDTO(course: course))
        return try JSONDecoder().decode(CourseExportDTO.self, from: data)
    }

    @Test func jsonRoundTrip_preservesSchedules() throws {
        let decoded = try encodedAndDecoded(makeCourse())

        let schedules = decoded.course.createSchedules()

        #expect(decoded.version == CourseExportDTO.currentVersion)
        #expect(schedules.map(\.time) == [ScheduledTime(hour: 9, minute: 5), ScheduledTime(hour: 21, minute: 0)])
        #expect(schedules.map(\.isNotificationEnabled) == [true, false])
    }

    @Test func jsonRoundTrip_preservesIntakes() throws {
        let decoded = try encodedAndDecoded(makeCourse())

        let intakes = decoded.course.createIntakes()

        #expect(intakes.count == 1)
        #expect(intakes.first?.date == day(-3))
        #expect(intakes.first?.dosage == Dosage(type: .press, amount: 2))
        #expect(intakes.first?.comment == "первый день")
    }

    @Test func jsonRoundTrip_preservesCustomName() throws {
        let decoded = try encodedAndDecoded(makeCourse())

        #expect(decoded.course.toCourse().customName == "Берёза, второй год")
    }

    /// Файлы, снятые до появления кастомного имени, читаются без него
    @Test func decoding_withoutCustomName_leavesItEmpty() throws {
        let data = try JSONEncoder().encode(CourseExportDTO(course: makeCourse()))
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var course = try #require(json["course"] as? [String: Any])
        course["customName"] = nil
        json["course"] = course
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(CourseExportDTO.self, from: legacyData)

        #expect(decoded.course.toCourse().customName.isEmpty)
    }

    @Test func jsonRoundTrip_preservesCourseAndPauses() throws {
        let decoded = try encodedAndDecoded(makeCourse())

        let course = decoded.course.toCourse()
        let pauses = decoded.course.createPauses()

        #expect(course.medicationId == "staloral_birch_pollen")
        #expect(course.takingYear == .second)
        #expect(course.startDate == day(-5))
        #expect(course.endDate == day(5))
        #expect(pauses.count == 1)
        #expect(pauses.first?.startDate == day(-2))
        #expect(pauses.first?.endDate == day(-1))
    }
}
