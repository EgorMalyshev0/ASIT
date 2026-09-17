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
        let schema = Schema([Course.self, Intake.self, IntakeSchedule.self, CoursePause.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        self.modelContext = ModelContext(modelContainer)
        self.notificationService = notificationService
        fetchCourses()
        refreshAllNotificationSchedules()
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
        course.schedules = [IntakeSchedule.makeDefault()]
        modelContext.insert(course)
        save()
        fetchCourses()
    }
    
    func updateCourse(_ course: Course) {
        save()
        fetchCourses()
    }
    
    func deleteCourse(_ course: Course) {
        // SwiftData каскадно удалит записи IntakeSchedule из БД, но это не отменяет уже
        // запланированные UNNotificationRequest в очереди iOS — делаем это явно
        for schedule in course.schedules {
            notificationService.cancelNotifications(schedule)
        }

        modelContext.delete(course)
        save()
        fetchCourses()
        refreshBadges()
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
        // ранние — приём за этот день есть, а более ранние без приёма считаются пропущенными
        let courseId = course.id
        let intakeDate = intake.date
        enqueueReminderTask { [self] in
            await notificationService.removeNotifications(forCourseId: courseId, upTo: intakeDate)
            await refreshBadgesForCurrentCourses()
        }
    }

    func updateIntake(_ intake: Intake) {
        save()
        fetchCourses()
        // Дата приёма могла поменяться — курс снова может ждать приёма
        refreshAllNotificationSchedules()
    }
    
    func deleteIntake(_ intake: Intake, from course: Course) {
        // TODO: здесь, возможно, достаточно удалить сам интейк
        if let index = course.intakes.firstIndex(where: { $0.id == intake.id }) {
            course.intakes.remove(at: index)
        }
        modelContext.delete(intake)
        save()
        fetchCourses()
        // Без приёма курс снова ждёт его, а сегодняшнее напоминание, убранное при отметке, нужно вернуть
        refreshAllNotificationSchedules()
    }
    
    // MARK: - IntakeSchedule CRUD

    func setNotificationsEnabled(_ isNotificationEnabled: Bool, course: Course) {
        let schedule = course.schedules.first ?? IntakeSchedule.makeDefault()
        schedule.isNotificationEnabled = isNotificationEnabled
        course.schedules = [schedule]
        save()
        fetchCourses()

        enqueueReminderTask { [self] in
            if isNotificationEnabled && canScheduleReminders(for: course) {
                await notificationService.scheduleNotifications(for: course, schedule: schedule)
            } else {
                notificationService.cancelNotifications(schedule)
            }
            await refreshBadgesForCurrentCourses()
        }
    }

    func updateIntakeTime(_ newTime: Date, course: Course) {
        let schedule = course.schedules.first ?? IntakeSchedule.makeDefault()
        schedule.time = ScheduledTime(date: newTime)
        course.schedules = [schedule]
        save()
        fetchCourses()

        enqueueReminderTask { [self] in
            notificationService.cancelNotifications(schedule)
            if schedule.isNotificationEnabled && canScheduleReminders(for: course) {
                await notificationService.scheduleNotifications(for: course, schedule: schedule)
            }
            await refreshBadgesForCurrentCourses()
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

        let reminders = course.schedules
        enqueueReminderTask { [self] in
            for schedule in reminders {
                notificationService.cancelNotifications(schedule)
            }
            await refreshBadgesForCurrentCourses()
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

        let enabledReminders = canScheduleReminders(for: course) ? course.schedules.filter(\.isNotificationEnabled) : []
        enqueueReminderTask { [self] in
            for schedule in enabledReminders {
                await notificationService.scheduleNotifications(for: course, schedule: schedule)
            }
            await refreshBadgesForCurrentCourses()
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
        let enabledReminders = canScheduleReminders(for: course) ? course.schedules.filter(\.isNotificationEnabled) : []
        enqueueReminderTask { [self] in
            await notificationService.removeNotifications(forCourseId: courseId, outsideOf: start, end)
            // Окно могло сдвинуться: например, старт перенесли на более раннюю дату
            for schedule in enabledReminders {
                await notificationService.scheduleNotifications(for: course, schedule: schedule)
            }
            await refreshBadgesForCurrentCourses()
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
    func refreshAllNotificationSchedules() -> Task<Void, Never> {
        let enabledPairs = courses.filter(canScheduleReminders).flatMap { course in
            course.schedules.filter(\.isNotificationEnabled).map { (course, $0) }
        }

        return enqueueReminderTask { [self] in
            for (course, schedule) in enabledPairs {
                await notificationService.scheduleNotifications(for: course, schedule: schedule)
            }
            await refreshBadgesForCurrentCourses()
        }
    }

    /// Пересчитывает бейдж и badge в pending-уведомлениях (см. `IntakeBadgeCalculator`) — после
    /// операций вне сервиса, например snooze, или когда пуш доставлен при открытом приложении и его
    /// content.badge система не применила
    @discardableResult
    func refreshBadges() -> Task<Void, Never> {
        enqueueReminderTask { [self] in
            await refreshBadgesForCurrentCourses()
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

        // Вариант и дозировку берём с прошлого приёма, а комментарий - нет: он относился к тому дню
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            variantId: lastIntake.variantId,
            dosage: lastIntake.dosage,
            comment: ""
        )

        addIntake(intake, to: course)
    }
    
    // MARK: - Import/Export
    
    func importCourse(from dto: CourseExportDTO) {
        let course = dto.course.toCourse()
        modelContext.insert(course)
        
        course.intakes.append(contentsOf: dto.course.createIntakes())
        course.schedules.append(contentsOf: dto.course.createSchedules())

        course.pauses.append(contentsOf: dto.course.createPauses())
        
        save()
        fetchCourses()
        
        // Планируем напоминания — только включённые, иначе импорт курса с выключенным
        // напоминанием тут же создавал бы живое уведомление в обход isNotificationEnabled. Курс на паузе и завершённый не планируем вовсе
        let enabledReminders = canScheduleReminders(for: course) ? course.schedules.filter(\.isNotificationEnabled) : []
        enqueueReminderTask { [self] in
            for schedule in enabledReminders {
                await notificationService.scheduleNotifications(for: course, schedule: schedule)
            }
            await refreshBadgesForCurrentCourses()
        }
    }

    // MARK: - Private

    /// Курсы читаем в момент выполнения, а не при постановке в очередь: к этому моменту часть
    /// захваченных моделей могла быть уже удалена из контекста
    @MainActor
    private func refreshBadgesForCurrentCourses() async {
        await notificationService.refreshBadges(for: courses)
    }

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

    func setNotificationsEnabled(_ isNotificationEnabled: Bool, course: Course) {}

    func updateIntakeTime(_ newTime: Date, course: Course) {}

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
        course.intakes.append(contentsOf: dto.course.createIntakes())
        course.schedules.append(contentsOf: dto.course.createSchedules())
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
            comment: ""
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
