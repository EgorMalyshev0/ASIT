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
    private var cancellables = Set<AnyCancellable>()

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        setupBindings()
    }

    func courseName(for course: Course) -> String {
        courseService.courseName(for: course)
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
}

