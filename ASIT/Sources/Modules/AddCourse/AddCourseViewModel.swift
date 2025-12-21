//
//  AddCourseViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation
import SwiftData

@Observable
final class AddCourseViewModel {
    var availableMedications = [Medication]()
    let takingYears = MedicationTakingYear.allCases
    var selectedMedicationId: String?
    var selectedYear: Int?
    var startDate: Date
    var endDate: Date

    var isFormValid: Bool {
        selectedMedicationId != nil && selectedYear != nil
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        startDate = .now
        endDate = .now.addingTimeInterval(60 * 60 * 24 * 180)
        fetchMedications()
    }

    func addCourse() {
        guard let selectedMedicationId,
              let selectedYear,
              let takingYear = MedicationTakingYear(rawValue: selectedYear)  else {
            return
        }

        let course = Course(
            medicationId: selectedMedicationId,
            takingYear: takingYear,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            isPaused: false,
            intakes: []
        )

        modelContext.insert(course)
    }

    private func fetchMedications() {
        guard let url = Bundle.main.url(forResource: "Medications", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            availableMedications = try decoder.decode([Medication].self, from: data)
        } catch {
            print("Failed to decode Medications: \(error)")
        }
    }
}
