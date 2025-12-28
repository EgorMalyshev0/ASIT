//
//  CourseManagementService.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import Foundation
import SwiftData
import Combine

final class CourseManagementService: ObservableObject, CourseManagementServiceProtocol {
    @Published private(set) var courses: [Course] = []
    
    var coursesPublisher: AnyPublisher<[Course], Never> {
        $courses.eraseToAnyPublisher()
    }
    
    let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init() {
        let schema = Schema([Course.self, Intake.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        self.modelContext = ModelContext(modelContainer)
        fetchCourses()
    }
    
    // MARK: - Course CRUD
    
    func addCourse(_ course: Course) {
        modelContext.insert(course)
        save()
        fetchCourses()
    }
    
    func updateCourse(_ course: Course) {
        save()
        fetchCourses()
    }
    
    func deleteCourse(_ course: Course) {
        modelContext.delete(course)
        save()
        fetchCourses()
    }
    
    func fetchCourses() {
        let descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        do {
            courses = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch courses: \(error)")
            courses = []
        }
    }
    
    // MARK: - Intake CRUD
    
    func addIntake(_ intake: Intake, to course: Course) {
        course.intakes.append(intake)
        save()
        fetchCourses()
    }
    
    func updateIntake(_ intake: Intake) {
        save()
        fetchCourses()
    }
    
    func deleteIntake(_ intake: Intake, from course: Course) {
        // TODO: здесь, возможно, достаточно удалить сам интейк
        if let index = course.intakes.firstIndex(where: { $0.id == intake.id }) {
            course.intakes.remove(at: index)
        }
        modelContext.delete(intake)
        save()
        fetchCourses()
    }
    
    // MARK: - Private
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

// MARK: - Mock for Testing

final class MockCourseManagementService: CourseManagementServiceProtocol {
    
    @Published private(set) var courses: [Course] = []
    
    var coursesPublisher: AnyPublisher<[Course], Never> {
        $courses.eraseToAnyPublisher()
    }
    
    func addCourse(_ course: Course) {
        courses.append(course)
    }
    
    func updateCourse(_ course: Course) {}
    
    func deleteCourse(_ course: Course) {
        courses.removeAll { $0.id == course.id }
    }
    
    func fetchCourses() {}
    
    func addIntake(_ intake: Intake, to course: Course) {
        course.intakes.append(intake)
    }
    
    func updateIntake(_ intake: Intake) {}
    
    func deleteIntake(_ intake: Intake, from course: Course) {
        if let index = course.intakes.firstIndex(where: { $0.id == intake.id }) {
            course.intakes.remove(at: index)
        }
    }
}

