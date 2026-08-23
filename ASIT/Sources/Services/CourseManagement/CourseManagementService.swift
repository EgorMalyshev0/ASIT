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
        // сразу кладем дефолтный выключенный ремайндер
        course.reminders = [Reminder.default]
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
        
        // Удаляем доставленные уведомления и обновляем badge
        NotificationService.shared.removeDeliveredNotifications(for: course)
        Task { @MainActor in
            await NotificationService.shared.updateBadgeCount()
        }
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

    func setReminderEnabled(_ isEnabled: Bool, course: Course) {
        let reminder = course.reminders.first ?? Reminder.default
        reminder.isEnabled = isEnabled
        course.reminders = [reminder]
        save()
        fetchCourses()

        if isEnabled {
            Task {
                await NotificationService.shared.scheduleReminder(for: course, reminder: reminder)
            }
        } else {
            NotificationService.shared.cancelReminder(reminder)
        }
    }

    func updateReminderTime(_ newTime: Date, course: Course) {
        let reminder = course.reminders.first ?? Reminder.default
        let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)

        reminder.hour = components.hour ?? Reminder.defaultHour
        reminder.minute = components.minute ?? Reminder.defaultMinute
        course.reminders = [reminder]
        save()
        fetchCourses()

        NotificationService.shared.cancelReminder(reminder)

        Task {
            await NotificationService.shared.scheduleReminder(for: course, reminder: reminder)
        }
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
            variantId: lastIntake.variantId,
            dosage: lastIntake.dosage,
            comment: nil
        )

        addIntake(intake, to: course)
    }
    
    // MARK: - Import/Export
    
    func importCourse(from dto: CourseExportDTO) {
        let course = dto.course.toCourse()
        modelContext.insert(course)
        
        // Добавляем интейки
        for intakeDTO in dto.course.intakes {
            let intake = intakeDTO.toIntake()
            course.intakes.append(intake)
        }
        
        // Добавляем напоминания
        for reminderDTO in dto.course.reminders {
            let reminder = reminderDTO.toReminder()
            course.reminders.append(reminder)
        }
        
        save()
        fetchCourses()
        
        // Планируем напоминания
        for reminder in course.reminders {
            Task {
                await NotificationService.shared.scheduleReminder(for: course, reminder: reminder)
            }
        }
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

    func setReminderEnabled(_ isEnabled: Bool, course: Course) {}

    func updateReminderTime(_ newTime: Date, course: Course) {}

    func handleTakenActionFromPush(courseId: UUID, date: Date) {}
    
    func importCourse(from dto: CourseExportDTO) {
        let course = dto.course.toCourse()
        for intakeDTO in dto.course.intakes {
            course.intakes.append(intakeDTO.toIntake())
        }
        for reminderDTO in dto.course.reminders {
            course.reminders.append(reminderDTO.toReminder())
        }
        courses.append(course)
    }

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
            variantId: "staloral_birch_pollen_10_ir_ml",
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
