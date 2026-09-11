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

    private let courseService: CourseManagementServiceProtocol
    private let medicationService: MedicationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.courseService = courseService
        self.medicationService = medicationService
        setupBindings()
    }

    func medicationName(for course: Course) -> String {
        medicationService.medication(withId: course.medicationId)?.name.ru ?? course.medicationId
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
        CourseSettingsViewModel(course: course, courseService: courseService, medicationService: medicationService)
    }

    private func setupBindings() {
        courseService.coursesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] courses in
                self?.courses = courses
            }
            .store(in: &cancellables)
    }
}

