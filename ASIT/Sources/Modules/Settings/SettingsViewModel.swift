//
//  SettingsViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import Combine

@Observable
final class SettingsViewModel {
    var courses: [Course] = []
    var medications: [Medication] = []
    
    private let courseService: CourseManagementServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        setupBindings()
        fetchMedications()
    }
    
    func medicationName(for course: Course) -> String {
        medications.first { $0.id == course.medicationId }?.name.ru ?? course.medicationId
    }
    
    func importCourse(from url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw CourseExportError.decodingFailed
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let data = try Data(contentsOf: url)
        let dto = try CourseExportService.importCourse(from: data)
        courseService.importCourse(from: dto)
    }

    func makeCourseSettingsViewModel(for course: Course) -> CourseSettingsViewModel {
        CourseSettingsViewModel(course: course, courseService: courseService)
    }

    private func setupBindings() {
        courseService.coursesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] courses in
                self?.courses = courses
            }
            .store(in: &cancellables)
    }
    
    private func fetchMedications() {
        guard let url = Bundle.main.url(forResource: "Medications", withExtension: "json") else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            medications = try decoder.decode([Medication].self, from: data)
        } catch {
            print("Failed to decode Medications: \(error)")
        }
    }
}

