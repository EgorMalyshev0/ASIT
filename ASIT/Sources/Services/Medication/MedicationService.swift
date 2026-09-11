//
//  MedicationService.swift
//  ASIT
//
//  Created by Egor Malyshev on 11.09.2026.
//

import Foundation

/// Справочник препаратов, загружается один раз из бандла (Medications.json).
final class MedicationService: MedicationServiceProtocol {
    private(set) var medications: [Medication] = []

    init() {
        loadMedications()
    }

    func medication(withId id: String) -> Medication? {
        medications.first { $0.id == id }
    }

    private func loadMedications() {
        guard let url = Bundle.main.url(forResource: "Medications", withExtension: "json") else {
            assertionFailure("Не найден файл с препаратами")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            medications = try JSONDecoder().decode([Medication].self, from: data)
        } catch {
            assertionFailure("Failed to decode Medications: \(error)")
            print("Failed to decode Medications: \(error)")
        }
    }
}

final class MockMedicationService: MedicationServiceProtocol {
    let medications: [Medication]

    init(medications: [Medication] = []) {
        self.medications = medications
    }

    func medication(withId id: String) -> Medication? {
        medications.first { $0.id == id }
    }
}
