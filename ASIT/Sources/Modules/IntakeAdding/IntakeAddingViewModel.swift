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
    private(set) var availableVariants: [Medication.Variant] = []
    
    var selectedVariantId: String? {
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
        selectedVariantId != nil && selectedDosage != nil
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
        guard let selectedVariantId, let selectedDosage else { return }
        
        // Если редактируем - удаляем старый приём
        if let existingIntake = existingIntake {
            courseService.deleteIntake(existingIntake, from: course)
        }
        
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            variantId: selectedVariantId,
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
            availableVariants = medication?.variants ?? []
            
            if let firstVariant = availableVariants.first {
                selectedVariantId = firstVariant.id
            }
        } catch {
            print("Failed to load medication: \(error)")
        }
    }
    
    private func prefillFromIntake() {
        // Приоритет: приём на эту дату > последний приём
        let targetIntake = existingIntake ?? course.lastIntake
        guard let targetIntake = targetIntake else { return }
        
        // Установить вариант
        if availableVariants.contains(where: { $0.id == targetIntake.variantId }) {
            selectedVariantId = targetIntake.variantId
        }
        
        // Установить дозировку
        if availableDosages.contains(targetIntake.dosage) {
            selectedDosage = targetIntake.dosage
        }
    }
    
    private func updateAvailableDosages() {
        guard let selectedVariantId,
              let variant = availableVariants.first(where: { $0.id == selectedVariantId }) else {
            availableDosages = []
            selectedDosage = nil
            return
        }
        
        availableDosages = variant.dosages
        
        // Попробовать сохранить выбранную дозировку если она есть в новом списке
        if let current = selectedDosage, availableDosages.contains(current) {
            return
        }
        
        selectedDosage = availableDosages.first
    }
}
