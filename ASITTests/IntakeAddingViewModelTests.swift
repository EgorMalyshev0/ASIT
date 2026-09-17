//
//  IntakeAddingViewModelTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 16.09.2026.
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct IntakeAddingViewModelTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    private func makeCourse() -> Course {
        Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .second,
            startDate: day(-5),
            endDate: day(5)
        )
    }

    private func makeIntake(on date: Date, comment: String) -> Intake {
        Intake(
            date: date,
            medicationId: "staloral_birch_pollen",
            variantId: "staloral_birch_pollen_10_ir_ml",
            dosage: Dosage(type: .press, amount: 2),
            comment: comment
        )
    }

    private func makeViewModel(course: Course, date: Date) -> IntakeAddingViewModel {
        IntakeAddingViewModel(
            course: course,
            date: date,
            courseService: MockCourseManagementService(),
            medicationService: MockMedicationService()
        )
    }

    @Test func comment_overLimit_isTrimmed() {
        let viewModel = makeViewModel(course: makeCourse(), date: day(0))

        viewModel.comment = String(repeating: "я", count: 500)
        viewModel.trimCommentToLimit()

        #expect(viewModel.comment.count == 200)
    }

    @Test func comment_withinLimit_isKeptAsIs() {
        let viewModel = makeViewModel(course: makeCourse(), date: day(0))

        viewModel.comment = "Всё хорошо"
        viewModel.trimCommentToLimit()

        #expect(viewModel.comment == "Всё хорошо")
    }

    @Test func prefill_doesNotCarryCommentFromLastIntake() {
        let course = makeCourse()
        course.intakes = [makeIntake(on: day(-1), comment: "болела голова")]

        let viewModel = makeViewModel(course: course, date: day(0))

        #expect(viewModel.comment.isEmpty)
    }

    @Test func prefill_whenEditing_usesCommentOfThatDay() {
        let course = makeCourse()
        course.intakes = [
            makeIntake(on: day(-1), comment: "болела голова"),
            makeIntake(on: day(0), comment: "всё спокойно")
        ]

        let viewModel = makeViewModel(course: course, date: day(0))

        #expect(viewModel.isEditing)
        #expect(viewModel.comment == "всё спокойно")
    }

    @Test func save_trimsWhitespaceOnlyCommentToEmpty() {
        let course = makeCourse()
        let viewModel = makeViewModel(course: course, date: day(0))
        viewModel.selectedVariantId = "staloral_birch_pollen_10_ir_ml"
        viewModel.selectedDosage = Dosage(type: .press, amount: 2)
        viewModel.comment = "   \n "

        viewModel.save()

        #expect(course.intakes.count == 1)
        #expect(course.intakes.first?.comment == "")
    }
}
