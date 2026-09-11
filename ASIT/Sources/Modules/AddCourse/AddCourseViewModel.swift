//
//  AddCourseViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation

@Observable
final class AddCourseViewModel {
    let takingYears = MedicationTakingYear.allCases
    var selectedMedicationId: String?
    var selectedYear: Int?
    var startDate: Date
    var endDate: Date

    var availableMedications: [Medication] {
        medicationService.medications
    }

    var isFormValid: Bool {
        selectedMedicationId != nil && selectedYear != nil
    }

    private let courseService: CourseManagementServiceProtocol
    private let medicationService: MedicationServiceProtocol

    init(courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.courseService = courseService
        self.medicationService = medicationService
        startDate = .now
        endDate = .now.addingTimeInterval(60 * 60 * 24 * 180)
    }

    func addCourse() {
        guard let selectedMedicationId,
              let selectedYear,
              let takingYear = MedicationTakingYear(rawValue: selectedYear) else {
            return
        }

        let course = Course(
            medicationId: selectedMedicationId,
            takingYear: takingYear,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            isPaused: false
        )

        courseService.addCourse(course)
    }
}
