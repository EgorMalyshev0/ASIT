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
        let schema = Schema([Course.self, Intake.self, Reminder.self])
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
    
    // MARK: - Reminder CRUD
    
    func addReminder(_ reminder: Reminder, to course: Course) {
        course.reminders.append(reminder)
        save()
        fetchCourses()
        Task {
            await NotificationService.shared.scheduleReminder(for: course, reminder: reminder)
        }
    }
    
    func deleteReminder(_ reminder: Reminder, from course: Course) {
        if let index = course.reminders.firstIndex(where: { $0.id == reminder.id }) {
            course.reminders.remove(at: index)
        }
        modelContext.delete(reminder)
        save()
        fetchCourses()
        NotificationService.shared.cancelReminder(reminder)
    }

    func handleTakenActionFromPush(courseId: UUID, date: Date) {
        guard let course = courses.first(where: { $0.id == courseId }),
              let lastIntake = course.lastIntake else {
            return
        }

        // Проверяем, нет ли уже приёма на эту дату
        guard !course.hasIntake(on: date) else {
            return
        }

        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            packageId: lastIntake.packageId,
            dosage: lastIntake.dosage,
            comment: nil
        )

        addIntake(intake, to: course)
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
    
    init(withMockData: Bool = false) {
        if withMockData {
            courses = Self.mockCourses
        }
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
    
    func addReminder(_ reminder: Reminder, to course: Course) {
        course.reminders.append(reminder)
    }
    
    func deleteReminder(_ reminder: Reminder, from course: Course) {
        if let index = course.reminders.firstIndex(where: { $0.id == reminder.id }) {
            course.reminders.remove(at: index)
        }
    }

    func handleTakenActionFromPush(courseId: UUID, date: Date) {}

    static var mockCourses: [Course] {
        // Курс с приёмами (будет показывать "Подтвердить приём")
        let courseWithIntakes = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            endDate: Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        )
        // Добавляем приём вчера
        let yesterdayIntake = Intake(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            medicationId: "staloral_birch_pollen",
            packageId: "bottle-10-ir",
            dosage: Dosage(type: .press, amount: 3),
            comment: nil
        )
        courseWithIntakes.intakes.append(yesterdayIntake)
        
        // Курс без приёмов (будет показывать "Добавить приём")
        let courseWithoutIntakes = Course(
            medicationId: "staloral_mites",
            takingYear: .second,
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            endDate: Calendar.current.date(byAdding: .day, value: 90, to: Date())!
        )
        
        return [courseWithIntakes, courseWithoutIntakes]
    }
}

