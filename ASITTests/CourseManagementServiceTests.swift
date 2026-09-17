//
//  CourseManagementServiceTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct CourseManagementServiceTests {
    private func makeService(notificationService: MockNotificationService = MockNotificationService()) -> CourseManagementService {
        CourseManagementService(inMemory: true, notificationService: notificationService, medicationService: MockMedicationService())
    }

    private func makeCourse() -> Course {
        Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: .now,
            endDate: .now.addingTimeInterval(60 * 24 * 60 * 60)
        )
    }

    // MARK: - addCourse

    @Test func addCourse_attachesDisabledDefaultReminder_andSchedulesNothing() {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()

        service.addCourse(course)

        #expect(course.schedules.count == 1)
        #expect(course.schedules.first?.isNotificationEnabled == false)
        #expect(notificationService.scheduledNotifications.isEmpty)
        #expect(notificationService.canceledNotifications.isEmpty)
    }

    // MARK: - setReminderEnabled

    @Test func setReminderEnabled_true_schedulesReminderForCourse() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.scheduledNotifications.count == 1)
        #expect(notificationService.scheduledNotifications.first?.schedule.id == course.schedules.first?.id)
        #expect(course.schedules.first?.isNotificationEnabled == true)
    }

    @Test func setReminderEnabled_false_cancelsReminder() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        service.setNotificationsEnabled(false, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.canceledNotifications.count == 1)
        #expect(course.schedules.first?.isNotificationEnabled == false)
    }

    @Test func setReminderEnabled_rapidToggleOnThenOff_endsUpCanceledNotScheduled() async {
        // Регрессия: быстрый вкл→выкл не должен закончиться так, что асинхронный schedule
        // выполнится ПОСЛЕ синхронного cancel и оставит "зависшее" уведомление.
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        service.setNotificationsEnabled(true, course: course)
        service.setNotificationsEnabled(false, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.callLog.last { $0 != "refreshBadges" }?.hasPrefix("cancel:") == true)
        #expect(notificationService.callLog.last == "refreshBadges")
    }

    // MARK: - updateReminderTime

    @Test func updateReminderTime_onEnabledReminder_cancelsThenReschedules() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        let newTime = Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: .now)!
        service.updateIntakeTime(newTime, course: course)
        await service.waitForPendingReminderTask()

        #expect(course.schedules.first?.time == ScheduledTime(hour: 18, minute: 15))
        #expect(notificationService.canceledNotifications.count == 1)
        #expect(notificationService.scheduledNotifications.count == 2, "исходное включение + перепланирование после смены времени")
    }

    @Test func updateReminderTime_onDisabledReminder_onlyCancelsDoesNotReschedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        let newTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        service.updateIntakeTime(newTime, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.canceledNotifications.count == 1)
        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    // MARK: - deleteCourse

    @Test func deleteCourse_cancelsAllItsReminders() {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        service.deleteCourse(course)

        #expect(notificationService.canceledNotifications.count == 1)
        #expect(service.courses.contains { $0.id == course.id } == false)
    }

    @Test func deleteCourse_refreshesBadges() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        await service.waitForPendingReminderTask()
        let refreshesBefore = notificationService.refreshBadgesCallCount

        service.deleteCourse(course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.refreshBadgesCallCount == refreshesBefore + 1)
    }

    @Test func deleteIntake_refreshesBadges() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        let intake = makeIntake(for: course, date: .now)
        service.addIntake(intake, to: course)
        await service.waitForPendingReminderTask()
        let refreshesBefore = notificationService.refreshBadgesCallCount

        service.deleteIntake(intake, from: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.refreshBadgesCallCount == refreshesBefore + 1)
    }

    // MARK: - addIntake

    @Test func addIntake_removesCourseNotificationsUpToIntakeDay_thenRefreshesBadges() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        course.startDate = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        service.addCourse(course)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        service.addIntake(makeIntake(for: course, date: yesterday), to: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.removedNotifications.count == 1)
        #expect(notificationService.removedNotifications.first?.courseId == course.id)
        // Контракт removeNotifications(forCourseId:upTo:) дневной — приём хранит день, а не момент отметки
        #expect(notificationService.removedNotifications.first.map {
            Calendar.current.isDate($0.upToDate, inSameDayAs: yesterday)
        } == true)
        #expect(notificationService.callLog.suffix(2) == ["removeNotifications:\(course.id)", "refreshBadges"])
    }

    // MARK: - importCourse

    @Test func importCourse_schedulesOnlyEnabledReminders() async {
        // Регрессия: импорт курса с выключенным напоминанием не должен тут же
        // создавать живое уведомление в обход isNotificationEnabled.
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)

        let sourceCourse = makeCourse()
        let enabledReminder = IntakeSchedule(hour: 9, minute: 0, isNotificationEnabled: true)
        let disabledReminder = IntakeSchedule(hour: 21, minute: 0, isNotificationEnabled: false)
        sourceCourse.schedules = [enabledReminder, disabledReminder]
        let dto = CourseExportDTO(course: sourceCourse)

        service.importCourse(from: dto)
        // scheduleReminder запускается в самостоятельном Task { ... }, не через enqueueReminderTask
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(notificationService.scheduledNotifications.count == 1)
        #expect(notificationService.scheduledNotifications.first?.schedule.isNotificationEnabled == true)
        #expect(notificationService.scheduledNotifications.first?.schedule.time.hour == 9)
    }

    @Test func importCourse_allRemindersDisabled_schedulesNothing() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)

        let sourceCourse = makeCourse()
        sourceCourse.schedules = [IntakeSchedule(hour: 9, minute: 0, isNotificationEnabled: false)]
        let dto = CourseExportDTO(course: sourceCourse)

        service.importCourse(from: dto)
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    // MARK: - addIntake restrictions

    private func makeIntake(for course: Course, date: Date) -> Intake {
        Intake(
            date: date,
            medicationId: course.medicationId,
            variantId: "staloral_birch_pollen_10_ir_ml",
            dosage: Dosage(type: .press, amount: 1),
            comment: ""
        )
    }

    @Test func addIntake_futureDate_isRejected() {
        let service = makeService()
        let course = makeCourse()
        service.addCourse(course)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        service.addIntake(makeIntake(for: course, date: tomorrow), to: course)

        #expect(course.intakes.isEmpty)
    }

    @Test func addIntake_pausedDay_isRejected() {
        let service = makeService()
        let course = makeCourse()
        service.addCourse(course)
        service.pauseCourse(course)

        service.addIntake(makeIntake(for: course, date: .now), to: course)

        #expect(course.intakes.isEmpty)
    }

    // MARK: - pauseCourse

    @Test func pauseCourse_withoutTodayIntake_startsToday_andCancelsReminders() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        service.pauseCourse(course)
        await service.waitForPendingReminderTask()

        #expect(course.isPaused)
        #expect(course.isPaused(on: .now))
        #expect(notificationService.canceledNotifications.count == 1)
        #expect(notificationService.callLog.suffix(2).first?.hasPrefix("cancel:") == true)
        #expect(notificationService.callLog.last == "refreshBadges")
    }

    @Test func pauseCourse_withTodayIntake_startsTomorrow() {
        let service = makeService()
        let course = makeCourse()
        service.addCourse(course)
        service.addIntake(makeIntake(for: course, date: .now), to: course)

        service.pauseCourse(course)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        #expect(course.isPaused)
        #expect(!course.isPaused(on: .now))
        #expect(course.isPaused(on: tomorrow))
    }

    @Test func pauseCourse_twice_createsSinglePause() {
        let service = makeService()
        let course = makeCourse()
        service.addCourse(course)

        service.pauseCourse(course)
        service.pauseCourse(course)

        #expect(course.pauses.count == 1)
    }

    @Test func setReminderEnabled_whilePaused_doesNotSchedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.pauseCourse(course)

        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        #expect(course.schedules.first?.isNotificationEnabled == true)
        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    @Test func refreshAllReminderSchedules_skipsPausedCourses() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setNotificationsEnabled(true, course: course)
        service.pauseCourse(course)
        await service.waitForPendingReminderTask()
        let scheduledBefore = notificationService.scheduledNotifications.count

        await service.refreshAllNotificationSchedules().value

        #expect(notificationService.scheduledNotifications.count == scheduledBefore)
    }

    @Test func handleTakenActionFromPush_pausedDay_addsNothing() {
        let service = makeService()
        let calendar = Calendar.current
        let course = makeCourse()
        course.startDate = calendar.date(byAdding: .day, value: -5, to: .now)!
        service.addCourse(course)
        service.addIntake(makeIntake(for: course, date: calendar.date(byAdding: .day, value: -2, to: .now)!), to: course)
        service.pauseCourse(course)

        service.handleTakenActionFromPush(courseId: course.id, date: .now)

        #expect(course.intakes.count == 1)
        #expect(!course.hasIntake(on: .now))
    }

    @Test func handleTakenActionFromPush_snoozedPastMidnight_recordsIntakeOnOriginalDay() async {
        // Snooze в 23:00 доставляется в 00:00 — приём должен лечь на исходный (вчерашний) день
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let calendar = Calendar.current
        let course = makeCourse()
        course.startDate = calendar.date(byAdding: .day, value: -5, to: .now)!
        service.addCourse(course)
        service.addIntake(makeIntake(for: course, date: calendar.date(byAdding: .day, value: -3, to: .now)!), to: course)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        let originalDate = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!

        service.handleTakenActionFromPush(courseId: course.id, date: originalDate)

        await service.waitForPendingReminderTask()

        #expect(course.hasIntake(on: yesterday))
        #expect(!course.hasIntake(on: .now))
        #expect(notificationService.removedNotifications.last.map {
            calendar.isDate($0.upToDate, inSameDayAs: originalDate)
        } == true)
    }

    // MARK: - resumeCourse

    @Test func resumeCourse_sameDayPause_removesPause_andReschedulesEnabledReminder() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setNotificationsEnabled(true, course: course)
        service.pauseCourse(course)
        await service.waitForPendingReminderTask()
        let scheduledBefore = notificationService.scheduledNotifications.count

        service.resumeCourse(course)
        await service.waitForPendingReminderTask()

        #expect(!course.isPaused)
        #expect(course.pauses.isEmpty)
        #expect(notificationService.scheduledNotifications.count == scheduledBefore + 1)
    }

    @Test func resumeCourse_disabledReminder_schedulesNothing() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.pauseCourse(course)

        service.resumeCourse(course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    @Test func resumeCourse_pastPause_closesPeriodAtToday() {
        let service = makeService()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let course = makeCourse()
        course.startDate = calendar.date(byAdding: .day, value: -10, to: today)!
        service.addCourse(course)
        course.pauses.append(CoursePause(startDate: threeDaysAgo))

        service.resumeCourse(course)

        #expect(!course.isPaused)
        #expect(course.pauses.count == 1)
        #expect(course.isPaused(on: threeDaysAgo))
        #expect(!course.isPaused(on: today))
    }

    // MARK: - updateCourseDates

    private func day(_ offset: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    /// Курс с -10 по +10 день от сегодня
    private func makeRunningCourse(in service: CourseManagementService) -> Course {
        let course = makeCourse()
        course.startDate = day(-10)
        course.endDate = day(10)
        service.addCourse(course)
        return course
    }

    @Test func updateCourseDates_normalizesDatesToStartOfDay() {
        let service = makeService()
        let course = makeRunningCourse(in: service)

        service.updateCourseDates(course, startDate: day(-5).addingTimeInterval(3600), endDate: day(20).addingTimeInterval(7200))

        #expect(course.startDate == day(-5))
        #expect(course.endDate == day(20))
    }

    @Test func updateCourseDates_startAfterEnd_isRejected() {
        let service = makeService()
        let course = makeRunningCourse(in: service)

        service.updateCourseDates(course, startDate: day(5), endDate: day(1))

        #expect(course.startDate == day(-10))
        #expect(course.endDate == day(10))
    }

    @Test func updateCourseDates_removesIntakesOutsideNewDates_keepsInside() {
        let service = makeService()
        let course = makeRunningCourse(in: service)
        for offset in [-9, -5, -3, -1] {
            service.addIntake(makeIntake(for: course, date: day(offset).addingTimeInterval(9 * 3600)), to: course)
        }

        service.updateCourseDates(course, startDate: day(-5), endDate: day(-2))

        #expect(course.intakes.count == 2)
        #expect(course.hasIntake(on: day(-5)))
        #expect(course.hasIntake(on: day(-3)))
    }

    @Test func updateCourseDates_pauseEntirelyOutside_isRemoved() {
        let service = makeService()
        let course = makeRunningCourse(in: service)
        course.pauses.append(CoursePause(startDate: day(-9), endDate: day(-7)))

        service.updateCourseDates(course, startDate: day(-5), endDate: day(10))

        #expect(course.pauses.isEmpty)
    }

    @Test func updateCourseDates_pauseCrossingNewStart_isClippedToStart() {
        let service = makeService()
        let course = makeRunningCourse(in: service)
        course.pauses.append(CoursePause(startDate: day(-8), endDate: day(-3)))

        service.updateCourseDates(course, startDate: day(-5), endDate: day(10))

        #expect(course.pauses.first?.startDate == day(-5))
        #expect(course.pauses.first?.endDate == day(-3))
    }

    @Test func updateCourseDates_openPause_endInPast_closesPauseAtDayAfterEnd() {
        let service = makeService()
        let course = makeRunningCourse(in: service)
        course.pauses.append(CoursePause(startDate: day(-6)))

        service.updateCourseDates(course, startDate: day(-10), endDate: day(-2))

        #expect(!course.isPaused)
        #expect(course.pauses.first?.startDate == day(-6))
        #expect(course.pauses.first?.endDate == day(-1))
    }

    @Test func updateCourseDates_openPause_endInFuture_staysOpen() {
        let service = makeService()
        let course = makeRunningCourse(in: service)
        course.pauses.append(CoursePause(startDate: day(-3)))

        service.updateCourseDates(course, startDate: day(-10), endDate: day(3))

        #expect(course.isPaused)
        #expect(course.pauses.first?.endDate == nil)
    }

    @Test func updateCourseDates_pauseStartingTomorrow_endToday_isRemoved() {
        let service = makeService()
        let course = makeRunningCourse(in: service)
        course.pauses.append(CoursePause(startDate: day(1)))

        service.updateCourseDates(course, startDate: day(-10), endDate: day(0))

        #expect(course.pauses.isEmpty)
    }

    @Test func updateCourseDates_removesOutsideNotifications_reschedulesEnabled_refreshesBadges() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeRunningCourse(in: service)
        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()
        let scheduledBefore = notificationService.scheduledNotifications.count

        service.updateCourseDates(course, startDate: day(-5), endDate: day(3))
        await service.waitForPendingReminderTask()

        #expect(notificationService.removedNotificationsOutsideCourse.count == 1)
        #expect(notificationService.removedNotificationsOutsideCourse.first?.startDate == day(-5))
        #expect(notificationService.removedNotificationsOutsideCourse.first?.endDate == day(3))
        #expect(notificationService.scheduledNotifications.count == scheduledBefore + 1)
        #expect(notificationService.callLog.suffix(3).first?.hasPrefix("removeNotificationsOutside:") == true)
        #expect(notificationService.callLog.last == "refreshBadges")
    }

    @Test func updateCourseDates_pausedCourse_doesNotReschedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeRunningCourse(in: service)
        service.setNotificationsEnabled(true, course: course)
        service.pauseCourse(course)
        await service.waitForPendingReminderTask()
        let scheduledBefore = notificationService.scheduledNotifications.count

        service.updateCourseDates(course, startDate: day(-5), endDate: day(20))
        await service.waitForPendingReminderTask()

        #expect(notificationService.scheduledNotifications.count == scheduledBefore)
        #expect(notificationService.removedNotificationsOutsideCourse.count == 1)
    }

    // MARK: - Completed course

    /// Курс с -10 по -1 день от сегодня — уже завершён
    private func makeCompletedCourse(in service: CourseManagementService) -> Course {
        let course = makeCourse()
        course.startDate = day(-10)
        course.endDate = day(-1)
        service.addCourse(course)
        return course
    }

    @Test func isCompleted_dependsOnEndDate_lastDayIsNotCompleted() {
        let course = makeCourse()
        course.startDate = day(-10)

        course.endDate = day(0)
        #expect(!course.isCompleted)

        course.endDate = day(-1)
        #expect(course.isCompleted)
    }

    @Test func completedCourse_isStillActiveOnItsPastDays() {
        let service = makeService()
        let course = makeCompletedCourse(in: service)

        #expect(course.isActive(on: day(-5)))
        #expect(!course.isActive(on: day(0)))
        #expect(service.activeCourses(on: day(-5)).contains { $0.id == course.id })
    }

    @Test func setReminderEnabled_completedCourse_doesNotSchedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCompletedCourse(in: service)

        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    @Test func updateReminderTime_completedCourse_doesNotSchedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCompletedCourse(in: service)
        course.schedules.first?.isNotificationEnabled = true

        service.updateIntakeTime(.now, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    @Test func refreshAllReminderSchedules_skipsCompletedCourses() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let running = makeRunningCourse(in: service)
        let completed = makeCompletedCourse(in: service)
        running.schedules.first?.isNotificationEnabled = true
        completed.schedules.first?.isNotificationEnabled = true

        await service.refreshAllNotificationSchedules().value

        #expect(notificationService.scheduledNotifications.map(\.course.id) == [running.id])
    }

    @Test func updateCourseDates_endInPast_removesNotifications_doesNotReschedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeRunningCourse(in: service)
        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()
        let scheduledBefore = notificationService.scheduledNotifications.count

        service.updateCourseDates(course, startDate: day(-10), endDate: day(-1))
        await service.waitForPendingReminderTask()

        #expect(course.isCompleted)
        #expect(notificationService.scheduledNotifications.count == scheduledBefore)
        #expect(notificationService.removedNotificationsOutsideCourse.first?.endDate == day(-1))
        #expect(notificationService.callLog.last == "refreshBadges")
    }

    @Test func updateCourseDates_extendCompletedCourse_reschedulesEnabledReminder() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCompletedCourse(in: service)
        service.setNotificationsEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        service.updateCourseDates(course, startDate: day(-10), endDate: day(5))
        await service.waitForPendingReminderTask()

        #expect(!course.isCompleted)
        #expect(notificationService.scheduledNotifications.count == 1)
    }

    @Test func pauseCourse_completedCourse_isIgnored() {
        let service = makeService()
        let course = makeCompletedCourse(in: service)

        service.pauseCourse(course)

        #expect(course.pauses.isEmpty)
    }

    @Test func importCourse_completedCourse_schedulesNothing() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let source = makeCourse()
        source.startDate = day(-10)
        source.endDate = day(-1)
        source.schedules = [IntakeSchedule(hour: 9, minute: 0, isNotificationEnabled: true)]

        service.importCourse(from: CourseExportDTO(course: source))
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(notificationService.scheduledNotifications.isEmpty)
    }

    @Test func handleTakenActionFromPush_dayOutsideCourse_addsNothing() {
        let service = makeService()
        let course = makeCompletedCourse(in: service)
        service.addIntake(makeIntake(for: course, date: day(-3)), to: course)

        service.handleTakenActionFromPush(courseId: course.id, date: .now)

        #expect(course.intakes.count == 1)
        #expect(!course.hasIntake(on: .now))
    }
}
