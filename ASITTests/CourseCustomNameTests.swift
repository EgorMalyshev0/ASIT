//
//  CourseCustomNameTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 17.09.2026.
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct CourseCustomNameTests {
    private let medicationId = "staloral_birch_pollen"
    private let medicationName = "Сталораль Аллерген пыльцы берёзы"

    private func makeCourse() -> Course {
        Course(
            medicationId: medicationId,
            takingYear: .first,
            startDate: .now,
            endDate: .now.addingTimeInterval(60 * 24 * 60 * 60)
        )
    }

    private func makeCourseService(withCatalog: Bool = true) -> MockCourseManagementService {
        let medications = withCatalog ? [
            Medication(
                id: medicationId,
                name: LocalizedName(ru: medicationName),
                therapyType: .slit,
                variants: []
            )
        ] : []

        return MockCourseManagementService(medicationService: MockMedicationService(medications: medications))
    }

    private func makeSettingsViewModel(
        course: Course,
        courseService: CourseManagementServiceProtocol? = nil
    ) -> CourseSettingsViewModel {
        CourseSettingsViewModel(course: course, courseService: courseService ?? makeCourseService())
    }

    // MARK: - Course

    @Test func newCourse_hasEmptyCustomName() {
        #expect(makeCourse().customName.isEmpty)
    }

    // MARK: - courseName

    @Test func courseName_withoutCustomName_fallsBackToMedicationName() {
        let course = makeCourse()

        #expect(makeCourseService().courseName(for: course) == medicationName)
    }

    @Test func courseName_withCustomName_usesIt() {
        let course = makeCourse()
        course.customName = "Берёза, второй год"

        #expect(makeCourseService().courseName(for: course) == "Берёза, второй год")
    }

    @Test func courseName_withUnknownMedication_fallsBackToMedicationId() {
        let course = makeCourse()

        #expect(makeCourseService(withCatalog: false).courseName(for: course) == medicationId)
    }

    // MARK: - CourseSettingsViewModel

    @Test func settingsState_withoutCustomName_showsMedicationName() {
        let viewModel = makeSettingsViewModel(course: makeCourse())

        #expect(viewModel.state.customName.isEmpty)
        #expect(viewModel.state.medicationName == medicationName)
        #expect(viewModel.state.name == medicationName)
    }

    @Test func settingsState_withCustomName_showsIt() {
        let course = makeCourse()
        course.customName = "Берёза"

        #expect(makeSettingsViewModel(course: course).state.name == "Берёза")
    }

    @Test func saveCustomName_blank_fallsBackToMedicationName() {
        let viewModel = makeSettingsViewModel(course: makeCourse())

        viewModel.saveCustomName("   ")

        #expect(viewModel.state.name == medicationName)
    }

    @Test func saveCustomName_savesTrimmedNameToCourse() {
        let course = makeCourse()
        let viewModel = makeSettingsViewModel(course: course)

        viewModel.saveCustomName("  Берёза  ")

        #expect(viewModel.state.customName == "Берёза")
        #expect(course.customName == "Берёза")
    }

    @Test func saveCustomName_blank_clearsCustomNameOnCourse() {
        let course = makeCourse()
        course.customName = "Берёза"
        let viewModel = makeSettingsViewModel(course: course)

        viewModel.saveCustomName("   ")

        #expect(course.customName.isEmpty)
    }
}
