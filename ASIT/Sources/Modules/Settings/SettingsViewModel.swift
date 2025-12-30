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
    
    func addReminder(hour: Int, minute: Int, to course: Course) {
        let reminder = Reminder(hour: hour, minute: minute)
        courseService.addReminder(reminder, to: course)
        
        Task {
            await NotificationService.shared.scheduleReminder(for: course, reminder: reminder)
        }
    }
    
    func deleteReminder(_ reminder: Reminder, from course: Course) {
        courseService.deleteReminder(reminder, from: course)
        NotificationService.shared.cancelReminder(for: course)
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

