//
//  MainViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import Combine

@Observable
final class MainViewModel {
    var selectedDate: Date = Date()
    var weekOffset: Int = 0
    var courses: [Course] = []
    var medications: [Medication] = []

    /// Активные курсы на выбранную дату
    var activeCoursesForSelectedDate: [Course] {
        courses.filter { course in
            let calendar = Calendar.current
            let startOfSelectedDate = calendar.startOfDay(for: selectedDate)
            let startOfCourseStart = calendar.startOfDay(for: course.startDate)
            let startOfCourseEnd = calendar.startOfDay(for: course.endDate)
            
            return startOfSelectedDate >= startOfCourseStart &&
                   startOfSelectedDate <= startOfCourseEnd &&
                   !course.isCompleted &&
                   !course.isPaused
        }
    }
    
    /// Количество подтверждённых приёмов на выбранную дату
    var confirmedIntakesCount: Int {
        activeCoursesForSelectedDate.filter { $0.hasIntake(on: selectedDate) }.count
    }
    
    /// Общее количество активных курсов на выбранную дату
    var totalCoursesCount: Int {
        activeCoursesForSelectedDate.count
    }

    private let courseService: CourseManagementServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        setupBindings()
        fetchMedications()
    }

    func medication(for course: Course) -> Medication? {
        medications.first { $0.id == course.medicationId }
    }
    
    func confirmIntake(for course: Course) {
        guard let lastIntake = course.lastIntake else { return }
        
        let intake = Intake(
            date: selectedDate,
            medicationId: course.medicationId,
            packageId: lastIntake.packageId,
            dosage: lastIntake.dosage,
            comment: nil
        )
        
        courseService.addIntake(intake, to: course)
    }
    
    func goToToday() {
        selectedDate = Date()
        weekOffset = 0
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
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
