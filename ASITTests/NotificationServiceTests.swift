//
//  NotificationServiceTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Testing
import UserNotifications
import Foundation
@testable import ASIT

@MainActor
struct NotificationServiceTests {
    private func makeCourse(reminders: [Reminder] = []) -> Course {
        let course = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: .now,
            endDate: .now.addingTimeInterval(60 * 24 * 60 * 60)
        )
        course.reminders = reminders
        return course
    }

    // MARK: - scheduleReminder

    @Test func scheduleReminder_createsDailyRequestWithReminderIdAsIdentifier() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 9, minute: 30, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        #expect(center.addedRequests.count == 1)
        #expect(center.addedRequests.first?.identifier == reminder.id.uuidString)
    }

    @Test func scheduleReminder_usesRepeatingCalendarTrigger_withReminderTime() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 14, minute: 45, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        let trigger = center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.repeats == true)
        #expect(trigger?.dateComponents.hour == 14)
        #expect(trigger?.dateComponents.minute == 45)
    }

    @Test func scheduleReminder_setsCourseAndReminderIdInUserInfo() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 10, minute: 0, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        let userInfo = center.addedRequests.first?.content.userInfo
        #expect(userInfo?["courseId"] as? String == course.id.uuidString)
        #expect(userInfo?["reminderId"] as? String == reminder.id.uuidString)
        #expect(userInfo?["originalDate"] == nil)
    }

    @Test func scheduleReminder_setsBadgeToDeliveredCountPlusOne() async {
        let center = MockNotificationCenter()
        center.deliveredCountToReturn = 3
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 10, minute: 0, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        let badge = center.addedRequests.first?.content.badge as? Int
        #expect(badge == 4)
    }

    // MARK: - scheduleOneTimeReminder (snooze)

    @Test func scheduleOneTimeReminder_usesIdentifierDistinctFromDailyReminder() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 10, minute: 0, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        // Ежедневное уже запланировано
        await service.scheduleReminder(for: course, reminder: reminder)
        // Снус на него же
        await service.scheduleOneTimeReminder(
            courseId: course.id,
            reminderId: reminder.id,
            originalDate: .now,
            afterInterval: 3600
        )

        #expect(center.addedRequests.count == 2)
        let identifiers = Set(center.addedRequests.map(\.identifier))
        #expect(identifiers.count == 2, "identifier снуса должен отличаться от ежедневного, иначе add() тихо заменит repeating-триггер на one-time")
        #expect(identifiers.contains(reminder.id.uuidString))
    }

    @Test func scheduleOneTimeReminder_usesNonRepeatingTimeIntervalTrigger() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminderId = UUID()

        await service.scheduleOneTimeReminder(
            courseId: UUID(),
            reminderId: reminderId,
            originalDate: .now,
            afterInterval: 3600
        )

        let trigger = center.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        #expect(trigger?.repeats == false)
        #expect(trigger?.timeInterval == 3600)
    }

    @Test func scheduleOneTimeReminder_storesOriginalDateInUserInfo() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)

        await service.scheduleOneTimeReminder(
            courseId: UUID(),
            reminderId: UUID(),
            originalDate: originalDate,
            afterInterval: 3600
        )

        let stored = center.addedRequests.first?.content.userInfo["originalDate"] as? TimeInterval
        #expect(stored == originalDate.timeIntervalSince1970)
    }

    // MARK: - cancelReminder

    @Test func cancelReminder_removesBothDailyAndSnoozeIdentifiers_pendingAndDelivered() {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 10, minute: 0, isEnabled: true)

        service.cancelReminder(reminder)

        let expectedIdentifiers = [reminder.id.uuidString, "\(reminder.id.uuidString)-snooze"]
        #expect(center.removedPendingIdentifiers.last == expectedIdentifiers)
        #expect(center.removedDeliveredIdentifiers.last == expectedIdentifiers)
    }

    // MARK: - removeDeliveredNotifications(for:)

    @Test func removeDeliveredNotifications_removesDailyAndSnoozeIdentifiers_forEveryReminder() {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminderA = Reminder(hour: 9, minute: 0, isEnabled: true)
        let reminderB = Reminder(hour: 20, minute: 0, isEnabled: true)
        let course = makeCourse(reminders: [reminderA, reminderB])

        service.removeDeliveredNotifications(for: course)

        let removed = Set(center.removedDeliveredIdentifiers.last ?? [])
        #expect(removed == Set([
            reminderA.id.uuidString, "\(reminderA.id.uuidString)-snooze",
            reminderB.id.uuidString, "\(reminderB.id.uuidString)-snooze"
        ]))
    }

    // MARK: - Authorization

    @Test func requestAuthorization_returnsCenterResult() async {
        let center = MockNotificationCenter()
        center.requestAuthorizationResult = .success(true)
        let service = NotificationService(notificationCenter: center)

        #expect(await service.requestAuthorization() == true)
    }

    @Test func requestAuthorization_returnsFalse_whenCenterThrows() async {
        struct SomeError: Error {}
        let center = MockNotificationCenter()
        center.requestAuthorizationResult = .failure(SomeError())
        let service = NotificationService(notificationCenter: center)

        #expect(await service.requestAuthorization() == false)
    }

    @Test func checkAuthorizationStatus_reflectsUnderlyingCenter() async {
        let center = MockNotificationCenter()
        center.authorizationStatusToReturn = .denied
        let service = NotificationService(notificationCenter: center)

        #expect(await service.checkAuthorizationStatus() == .denied)
    }

    // MARK: - Badge

    @Test func updateBadgeCount_setsBadgeToCurrentDeliveredCount() async {
        let center = MockNotificationCenter()
        center.deliveredCountToReturn = 5
        let service = NotificationService(notificationCenter: center)

        await service.updateBadgeCount()

        #expect(center.badgeCounts == [5])
    }

    @Test func clearBadge_setsBadgeToZero() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)

        await service.clearBadge()

        #expect(center.badgeCounts == [0])
    }

    // MARK: - Setup

    @Test func init_registersCategoryWithTakenAndSnoozeActions() {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        _ = service

        let category = center.setCategories.first
        #expect(center.setCategories.count == 1)
        #expect(category?.identifier == NotificationService.categoryIdentifier)
        let actionIdentifiers = Set(category?.actions.map(\.identifier) ?? [])
        #expect(actionIdentifiers == [
            NotificationService.takenActionIdentifier,
            NotificationService.snoozeActionIdentifier
        ])
    }
}
