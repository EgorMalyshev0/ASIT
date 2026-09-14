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
        
        // Убираем уведомления курса (и ещё не пришедшие, и уже доставленные) на день приёма и более
        // ранние — приём за этот день есть, а более ранние без приёма считаются пропущенными.
        // Badge обновляем уже после удаления
        let courseId = course.id
        let intakeDate = intake.date
        enqueueReminderTask { [notificationService] in
            await notificationService.removeNotifications(forCourseId: courseId, upTo: intakeDate)
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
            if isEnabled && canScheduleReminders(for: course) {
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
            if reminder.isEnabled && canScheduleReminders(for: course) {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
        }
    }

    // MARK: - Pause

    func pauseCourse(_ course: Course) {
        guard !course.isPaused, !course.isCompleted else {
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

        let enabledReminders = canScheduleReminders(for: course) ? course.reminders.filter(\.isEnabled) : []
        enqueueReminderTask { [notificationService] in
            for reminder in enabledReminders {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
        }
    }

    // MARK: - Dates

    func updateCourseDates(_ course: Course, startDate: Date, endDate: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else {
            return
        }

        // Приёмы вне новых дат удаляем — пользователь подтвердил это заранее
        let removedIntakes = course.intakes(outsideOf: start, end)
        let removedIntakeIds = Set(removedIntakes.map(\.id))
        course.intakes.removeAll { removedIntakeIds.contains($0.id) }
        removedIntakes.forEach(modelContext.delete)

        for pause in course.pauses {
            let isPauseLeft = clipPause(pause, courseStart: start, courseEnd: end)
            if !isPauseLeft {
                course.pauses.removeAll { $0.id == pause.id }
                modelContext.delete(pause)
            }
        }

        course.startDate = start
        course.endDate = end
        save()
        fetchCourses()

        let courseId = course.id
        // Курс на паузе или уже завершённый (дату окончания перенесли в прошлое) не планируем
        let enabledReminders = canScheduleReminders(for: course) ? course.reminders.filter(\.isEnabled) : []
        enqueueReminderTask { [notificationService] in
            await notificationService.removeNotifications(forCourseId: courseId, outsideOf: start, end)
            // Окно могло сдвинуться: например, старт перенесли на более раннюю дату
            for reminder in enabledReminders {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
            await notificationService.updateBadgeCount()
        }
    }

    /// Обрезает паузу по границам курса [courseStart, courseEnd]. Возвращает false, если от паузы
    /// ничего не осталось и её нужно удалить
    private func clipPause(_ pause: CoursePause, courseStart: Date, courseEnd: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Паузы полуоткрытые, поэтому граница — день после окончания курса
        let dayAfterCourse = calendar.date(byAdding: .day, value: 1, to: courseEnd) ?? courseEnd

        let startDate = max(calendar.startOfDay(for: pause.startDate), courseStart)
        let endDate: Date?
        if let pauseEnd = pause.endDate {
            endDate = min(calendar.startOfDay(for: pauseEnd), dayAfterCourse)
        } else {
            // Не снятая пауза у уже закончившегося курса закрывается его окончанием
            endDate = dayAfterCourse <= today ? dayAfterCourse : nil
        }

        guard startDate < (endDate ?? dayAfterCourse) else {
            return false
        }
        pause.startDate = startDate
        pause.endDate = endDate
        return true
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
        let enabledPairs = courses.filter(canScheduleReminders).flatMap { course in
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

        // Проверяем, нет ли уже приёма на эту дату, попадает ли она в даты курса и не на паузе ли курс
        guard !course.hasIntake(on: date), course.isActive(on: date), course.canAddIntake(on: date) else {
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
        // напоминанием тут же создавал бы живое уведомление в обход isEnabled. Курс на паузе и завершённый не планируем вовсе
        for reminder in course.reminders where reminder.isEnabled && canScheduleReminders(for: course) {
            Task {
                await notificationService.scheduleReminder(for: course, reminder: reminder)
            }
        }
    }

    // MARK: - Private

    /// Напоминания нужны только курсу, который не на паузе и ещё не завершён
    private func canScheduleReminders(for course: Course) -> Bool {
        !course.isPaused && !course.isCompleted
    }

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
        guard !course.isPaused, !course.isCompleted else {
            return
        }
        course.pauses.append(CoursePause(startDate: Calendar.current.startOfDay(for: Date())))
    }

    func resumeCourse(_ course: Course) {
        course.pauses.removeAll { $0.endDate == nil }
    }

    func updateCourseDates(_ course: Course, startDate: Date, endDate: Date) {
        let removedIntakeIds = Set(course.intakes(outsideOf: startDate, endDate).map(\.id))
        course.intakes.removeAll { removedIntakeIds.contains($0.id) }
        course.startDate = Calendar.current.startOfDay(for: startDate)
        course.endDate = Calendar.current.startOfDay(for: endDate)
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
