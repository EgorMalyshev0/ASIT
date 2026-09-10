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
        CourseManagementService(inMemory: true, notificationService: notificationService)
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

        #expect(course.reminders.count == 1)
        #expect(course.reminders.first?.isEnabled == false)
        #expect(notificationService.scheduledReminders.isEmpty)
        #expect(notificationService.canceledReminders.isEmpty)
    }

    // MARK: - setReminderEnabled

    @Test func setReminderEnabled_true_schedulesReminderForCourse() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        service.setReminderEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.scheduledReminders.count == 1)
        #expect(notificationService.scheduledReminders.first?.reminder.id == course.reminders.first?.id)
        #expect(course.reminders.first?.isEnabled == true)
    }

    @Test func setReminderEnabled_false_cancelsReminder() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setReminderEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        service.setReminderEnabled(false, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.canceledReminders.count == 1)
        #expect(course.reminders.first?.isEnabled == false)
    }

    @Test func setReminderEnabled_rapidToggleOnThenOff_endsUpCanceledNotScheduled() async {
        // Регрессия: быстрый вкл→выкл не должен закончиться так, что асинхронный schedule
        // выполнится ПОСЛЕ синхронного cancel и оставит "зависшее" уведомление.
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        service.setReminderEnabled(true, course: course)
        service.setReminderEnabled(false, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.callLog.last?.hasPrefix("cancel:") == true)
    }

    // MARK: - updateReminderTime

    @Test func updateReminderTime_onEnabledReminder_cancelsThenReschedules() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)
        service.setReminderEnabled(true, course: course)
        await service.waitForPendingReminderTask()

        let newTime = Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: .now)!
        service.updateReminderTime(newTime, course: course)
        await service.waitForPendingReminderTask()

        #expect(course.reminders.first?.hour == 18)
        #expect(course.reminders.first?.minute == 15)
        #expect(notificationService.canceledReminders.count == 1)
        #expect(notificationService.scheduledReminders.count == 2, "исходное включение + перепланирование после смены времени")
    }

    @Test func updateReminderTime_onDisabledReminder_onlyCancelsDoesNotReschedule() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        let newTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        service.updateReminderTime(newTime, course: course)
        await service.waitForPendingReminderTask()

        #expect(notificationService.canceledReminders.count == 1)
        #expect(notificationService.scheduledReminders.isEmpty)
    }

    // MARK: - deleteCourse

    @Test func deleteCourse_cancelsAllItsReminders() {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        service.deleteCourse(course)

        #expect(notificationService.canceledReminders.count == 1)
        #expect(service.courses.contains { $0.id == course.id } == false)
    }

    // MARK: - addIntake

    @Test func addIntake_removesDeliveredNotifications_andUpdatesBadge() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)
        let course = makeCourse()
        service.addCourse(course)

        let intake = Intake(
            date: .now,
            medicationId: course.medicationId,
            variantId: "staloral_birch_pollen_10_ir_ml",
            dosage: Dosage(type: .press, amount: 1),
            comment: nil
        )
        service.addIntake(intake, to: course)

        // updateBadgeCount запускается в отдельном Task { @MainActor in ... } — дождаться следующего runloop tick
        await Task.yield()

        #expect(notificationService.coursesWithRemovedDeliveredNotifications.count == 1)
        #expect(notificationService.coursesWithRemovedDeliveredNotifications.first?.id == course.id)
    }

    // MARK: - importCourse

    @Test func importCourse_schedulesOnlyEnabledReminders() async {
        // Регрессия: импорт курса с выключенным напоминанием не должен тут же
        // создавать живое уведомление в обход isEnabled.
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)

        let sourceCourse = makeCourse()
        let enabledReminder = Reminder(hour: 9, minute: 0, isEnabled: true)
        let disabledReminder = Reminder(hour: 21, minute: 0, isEnabled: false)
        sourceCourse.reminders = [enabledReminder, disabledReminder]
        let dto = CourseExportDTO(course: sourceCourse)

        service.importCourse(from: dto)
        // scheduleReminder запускается в самостоятельном Task { ... }, не через enqueueReminderTask
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(notificationService.scheduledReminders.count == 1)
        #expect(notificationService.scheduledReminders.first?.reminder.isEnabled == true)
        #expect(notificationService.scheduledReminders.first?.reminder.hour == 9)
    }

    @Test func importCourse_allRemindersDisabled_schedulesNothing() async {
        let notificationService = MockNotificationService()
        let service = makeService(notificationService: notificationService)

        let sourceCourse = makeCourse()
        sourceCourse.reminders = [Reminder(hour: 9, minute: 0, isEnabled: false)]
        let dto = CourseExportDTO(course: sourceCourse)

        service.importCourse(from: dto)
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(notificationService.scheduledReminders.isEmpty)
    }
}
