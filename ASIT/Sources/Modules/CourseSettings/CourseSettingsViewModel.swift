//
//  CourseSettingsViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import Foundation

@Observable
final class CourseSettingsViewModel {
    let course: Course
    
    private(set) var medication: Medication?
    private(set) var availablePackages: [Medication.Package] = []
    
    var selectedPackageId: String? {
        didSet {
            updateAvailableDosages()
        }
    }
    var selectedDosage: Dosage?
    
    private(set) var availableDosages: [Dosage] = []
    
    private let courseService: CourseManagementServiceProtocol
    
    init(course: Course, courseService: CourseManagementServiceProtocol) {
        self.course = course
        self.courseService = courseService
        loadMedication()
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
    
    private func updateAvailableDosages() {
        guard let selectedPackageId,
              let package = availablePackages.first(where: { $0.id == selectedPackageId }) else {
            availableDosages = []
            selectedDosage = nil
            return
        }
        
        availableDosages = package.dosages
        selectedDosage = availableDosages.first
    }
}

