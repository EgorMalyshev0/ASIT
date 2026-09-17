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
    /// Имя курса: заданное пользователем, иначе — название препарата
    private(set) var courseName: String = ""
    private(set) var availableVariants: [Medication.Variant] = []
    
    var selectedVariantId: String? {
        didSet {
            updateAvailableDosages()
        }
    }
    var selectedDosage: Dosage?
    var comment: String = ""
    
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
        selectedVariantId != nil && selectedDosage != nil && course.canAddIntake(on: date)
    }
    
    private let courseService: CourseManagementServiceProtocol
    private let medicationService: MedicationServiceProtocol

    init(course: Course, date: Date, courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.course = course
        self.date = date
        self.courseService = courseService
        self.medicationService = medicationService
        loadMedication()
        prefillFromIntake()
    }
    
    /// Обрезает комментарий до лимита. Вызывается из onChange, а не из сеттера или didSet:
    /// там обрезанное значение совпадает с уже сохранённым, изменения состояния нет,
    /// и TextField оставляет у себя набранный текст
    func trimCommentToLimit() {
        guard comment.count > Constants.commentMaxLength else {
            return
        }

        comment = String(comment.prefix(Constants.commentMaxLength))
    }
    
    /// Сколько символов комментария осталось до лимита
    var commentRemainingCount: Int? {
        let remainingCount = Constants.commentMaxLength - comment.count
        return remainingCount <= Constants.commentMinRemainingCount ? remainingCount : nil
    }
    
    func save() {
        // Проверяем до удаления старого приёма, иначе при отказе в addIntake потеряли бы его
        guard let selectedVariantId, let selectedDosage, course.canAddIntake(on: date) else { return }
        
        // Если редактируем - удаляем старый приём
        if let existingIntake = existingIntake {
            courseService.deleteIntake(existingIntake, from: course)
        }
        
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            variantId: selectedVariantId,
            dosage: selectedDosage,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        courseService.addIntake(intake, to: course)
    }

    func delete() {
        guard let existingIntake else { return }

        courseService.deleteIntake(existingIntake, from: course)
    }

    private func loadMedication() {
        medication = medicationService.medication(withId: course.medicationId)
        courseName = courseService.courseName(for: course)
        availableVariants = medication?.variants ?? []

        if let firstVariant = availableVariants.first {
            selectedVariantId = firstVariant.id
        }
    }
    
    private func prefillFromIntake() {
        // Комментарий подставляем только при редактировании: с прошлого приёма он не переносится
        comment = existingIntake?.comment ?? ""
        
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

extension IntakeAddingViewModel {
    private enum Constants {
        static let commentMaxLength = 200
        static let commentMinRemainingCount = 30
    }
}
