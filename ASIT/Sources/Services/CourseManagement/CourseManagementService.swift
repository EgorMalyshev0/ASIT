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
    private let notificationService: NotificationServiceProtocol

    /// Последняя запущенная задача планирования/отмены уведомлений
    private var reminderSchedulingTask: Task<Void, Never>?

    init(inMemory: Bool = false, notificationService: NotificationServiceProtocol) {
        let schema = Schema([Course.self, Intake.self, Reminder.self, CoursePause.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        self.modelContext = ModelContext(modelContainer)
        self.notificationService = notificationService
        fetchCourses()
        refreshAllReminderSchedules()
    }

    #if DEBUG
    /// Дожидается завершения текущей отложенной операции планирования/отмены уведомлений — используется в тестах.
    func waitForPendingReminderTask() async {
        await reminderSchedulingTask?.value
    }
    #endif
    
    // MARK: - Course CRUD
    
    func addCourse(_ course: Course) {
        // сразу кладем дефолтный выключенный ремайндер
        course.reminders = [Reminder.makeDefault()]
        modelContext.insert(course)
        save()
        fetchCourses()
    }
    
    func updateCourse(_ course: Course) {
        save()
        fetchCourses()
    }
    
    func deleteCourse(_ course: Course) {
        // SwiftData каскадно удалит записи Reminder из БД, но это не отменяет уже
        // запланированные UNNotificationRequest в очереди iOS — делаем это явно
        for reminder in course.reminders {
            notificationService.cancelReminder(reminder)
        }

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

    func activeCourses(on date: Date) -> [Course] {
        courses.filter { $0.isActive(on: date) }
    }

    func trackableCourses(on date: Date) -> [Course] {
        courses.filter { $0.isActive(on: date) && !$0.isPaused(on: date) }
    }
    
    // MARK: - Intake CRUD
    
    func addIntake(_ intake: Intake, to course: Course) {
        // Приёмы на будущие дни и на дни паузы запрещены
        guard course.canAddIntake(on: intake.date) else {
            return
        }

        course.intakes.append(intake)
        save()
        fetchCourses()
        
        // Удаляем доставленные уведомления и обновляем badge
        notificationService.removeDeliveredNotifications(for: course)

        // Если приём отмечен на сегодня — отменяем ещё не сработавшее сегодняшнее напоминание,
        // чтобы оно не пришло после того, как приём уже состоялся
        if Calendar.current.isDateInToday(intake.date) {
            for reminder in course.reminders {
                notificationService.cancelTodayOccurrence(for: reminder, referenceDate: intake.date)
            }
        }

        Task { @MainActor in
            await notificationService.updateBadgeCount()
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
        let reminder = course.reminders.first ?? Reminder.makeDefault()
        reminder.isEnabled = isEnabled
        course.reminders = [reminder]
        save()
        fetchCourses()

        enqueueReminderTask { [self] in
            if isEnabled && !course.isPaused {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            } else {
                notificationService.cancelReminder(reminder)
            }
        }
    }

    func updateReminderTime(_ newTime: Date, course: Course) {
        let reminder = course.reminders.first ?? Reminder.makeDefault()
        let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)

        reminder.hour = components.hour ?? Reminder.defaultHour
        reminder.minute = components.minute ?? Reminder.defaultMinute
        course.reminders = [reminder]
        save()
        fetchCourses()

        enqueueReminderTask { [self] in
            notificationService.cancelReminder(reminder)
            if reminder.isEnabled && !course.isPaused {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
        }
    }

    // MARK: - Pause

    func pauseCourse(_ course: Course) {
        guard !course.isPaused else {
            return
        }

        // Если приём на сегодня уже отмечен, пауза начинается с завтра — чтобы день не оказался
        // одновременно и на паузе, и с подтверждённым приёмом
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = course.hasIntake(on: today)
            ? calendar.date(byAdding: .day, value: 1, to: today) ?? today
            : today

        course.pauses.append(CoursePause(startDate: startDate))
        save()
        fetchCourses()

        let reminders = course.reminders
        enqueueReminderTask { [notificationService] in
            for reminder in reminders {
                notificationService.cancelReminder(reminder)
            }
            await notificationService.updateBadgeCount()
        }
    }

    func resumeCourse(_ course: Course) {
        guard let pause = course.activePause else {
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        if pause.startDate >= today {
            // Пауза ещё не успела захватить ни одного прошедшего дня — хранить её незачем
            course.pauses.removeAll { $0.id == pause.id }
            modelContext.delete(pause)
        } else {
            pause.endDate = today
        }
        save()
        fetchCourses()

        let enabledReminders = course.reminders.filter(\.isEnabled)
        enqueueReminderTask { [notificationService] in
            for reminder in enabledReminders {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
        }
    }

    /// Выполняет операции планирования/отмены уведомлений строго в порядке вызова,
    /// дожидаясь предыдущей операции перед началом следующей
    @discardableResult
    private func enqueueReminderTask(_ operation: @escaping () async -> Void) -> Task<Void, Never> {
        let previous = reminderSchedulingTask
        let task = Task {
            await previous?.value
            await operation()
        }
        reminderSchedulingTask = task
        return task
    }

    /// Дозаполняет окно материализованных уведомлений для всех включённых напоминаний — вызывается
    /// при холодном старте, возврате приложения в foreground и по BGAppRefreshTask, чтобы окно не
    /// истощалось, если пользователь долго не открывает приложение и не взаимодействует с пушами.
    /// Идемпотентен (scheduleReminder безопасно перевызывать) — дублирующиеся запросы просто
    /// заменяют существующие с теми же идентификаторами. Возвращает Task, чтобы вызывающий (например,
    /// обработчик BGAppRefreshTask) при желании мог дождаться завершения.
    @discardableResult
    func refreshAllReminderSchedules() -> Task<Void, Never> {
        let enabledPairs = courses.filter { !$0.isPaused }.flatMap { course in
            course.reminders.filter(\.isEnabled).map { (course, $0) }
        }

        return enqueueReminderTask { [notificationService] in
            for (course, reminder) in enabledPairs {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
        }
    }

    func handleTakenActionFromPush(courseId: UUID, date: Date) {
        guard let course = courses.first(where: { $0.id == courseId }),
              let lastIntake = course.lastIntake else {
            return
        }

        // Проверяем, нет ли уже приёма на эту дату и не на паузе ли курс
        guard !course.hasIntake(on: date), course.canAddIntake(on: date) else {
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

        course.pauses.append(contentsOf: dto.course.createPauses())
        
        save()
        fetchCourses()
        
        // Планируем напоминания — только включённые, иначе импорт курса с выключенным
        // напоминанием тут же создавал бы живое уведомление в обход isEnabled. Курс на паузе не планируем вовсе
        for reminder in course.reminders where reminder.isEnabled && !course.isPaused {
            Task {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
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

    func activeCourses(on date: Date) -> [Course] {
        courses.filter { $0.isActive(on: date) }
    }

    func trackableCourses(on date: Date) -> [Course] {
        courses.filter { $0.isActive(on: date) && !$0.isPaused(on: date) }
    }
    
    func addIntake(_ intake: Intake, to course: Course) {
        guard course.canAddIntake(on: intake.date) else {
            return
        }
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

    func pauseCourse(_ course: Course) {
        guard !course.isPaused else {
            return
        }
        course.pauses.append(CoursePause(startDate: Calendar.current.startOfDay(for: Date())))
    }

    func resumeCourse(_ course: Course) {
        course.pauses.removeAll { $0.endDate == nil }
    }

    func handleTakenActionFromPush(courseId: UUID, date: Date) {}
    
    func importCourse(from dto: CourseExportDTO) {
        let course = dto.course.toCourse()
        for intakeDTO in dto.course.intakes {
            course.intakes.append(intakeDTO.toIntake())
        }
        for reminderDTO in dto.course.reminders {
            course.reminders.append(reminderDTO.toReminder())
        }
        course.pauses.append(contentsOf: dto.course.createPauses())
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
