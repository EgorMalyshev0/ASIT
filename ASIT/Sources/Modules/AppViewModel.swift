//
//  AppViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Foundation
import Combine

@Observable
final class AppViewModel {
    private(set) var hasCourses: Bool

    private let courseService: CourseManagementServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        hasCourses = !courseService.courses.isEmpty
        setupBindings()
    }

    private func setupBindings() {
        courseService.coursesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] courses in
                self?.hasCourses = !courses.isEmpty
            }
            .store(in: &cancellables)
    }
}
