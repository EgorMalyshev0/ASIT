//
//  IntakeAddingViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import Foundation

@Observable
final class IntakeAddingViewModel {
    let course: Course
    let date: Date
    
    private(set) var medication: Medication?
    private(set) var availablePackages: [Medication.Package] = []
    
    var selectedPackageId: String? {
        didSet {
            updateAvailableDosages()
        }
    }
    var selectedDosage: Dosage?
    
    private(set) var availableDosages: [Dosage] = []
    
    /// Приём на эту дату (если есть - редактируем)
    private var existingIntake: Intake? {
        course.intake(on: date)
    }
    
    /// Редактируем существующий приём?
    var isEditing: Bool {
        existingIntake != nil
    }
    
    var canSave: Bool {
        selectedPackageId != nil && selectedDosage != nil
    }
    
    private let courseService: CourseManagementServiceProtocol
    
    init(course: Course, date: Date, courseService: CourseManagementServiceProtocol) {
        self.course = course
        self.date = date
        self.courseService = courseService
        loadMedication()
        prefillFromIntake()
    }
    
    func save() {
        guard let selectedPackageId, let selectedDosage else { return }
        
        // Если редактируем - удаляем старый приём
        if let existingIntake = existingIntake {
            courseService.deleteIntake(existingIntake, from: course)
        }
        
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            packageId: selectedPackageId,
            dosage: selectedDosage,
            comment: nil
        )
        
        courseService.addIntake(intake, to: course)
    }

    func delete() {
        guard let existingIntake else { return }

        courseService.deleteIntake(existingIntake, from: course)
    }

    private func loadMedication() {
        guard let url = Bundle.main.url(forResource: "Medications", withExtension: "json") else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let medications = try JSONDecoder().decode([Medication].self, from: data)
            medication = medications.first { $0.id == course.medicationId }
            availablePackages = medication?.packages ?? []
            
            if let firstPackage = availablePackages.first {
                selectedPackageId = firstPackage.id
            }
        } catch {
            print("Failed to load medication: \(error)")
        }
    }
    
    private func prefillFromIntake() {
        // Приоритет: приём на эту дату > последний приём
        let targetIntake = existingIntake ?? course.lastIntake
        guard let targetIntake = targetIntake else { return }
        
        // Установить упаковку
        if availablePackages.contains(where: { $0.id == targetIntake.packageId }) {
            selectedPackageId = targetIntake.packageId
        }
        
        // Установить дозировку
        if availableDosages.contains(targetIntake.dosage) {
            selectedDosage = targetIntake.dosage
        }
    }
    
    private func updateAvailableDosages() {
        guard let selectedPackageId,
              let package = availablePackages.first(where: { $0.id == selectedPackageId }) else {
            availableDosages = []
            selectedDosage = nil
            return
        }
        
        availableDosages = package.dosages
        
        // Попробовать сохранить выбранную дозировку если она есть в новом списке
        if let current = selectedDosage, availableDosages.contains(current) {
            return
        }
        
        selectedDosage = availableDosages.first
    }
}
