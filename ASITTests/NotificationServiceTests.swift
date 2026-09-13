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
    private func makeCourse(startDate: Date = .now, reminders: [Reminder] = []) -> Course {
        let course = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: startDate,
            endDate: .now.addingTimeInterval(60 * 24 * 60 * 60)
        )
        course.reminders = reminders
        return course
    }

    /// Повторяет форматирование идентификатора конкретного дня окна из NotificationService —
    /// сама реализация приватна, поэтому дублируем формат здесь, чтобы независимо проверить контракт
    private func dailyIdentifier(for reminderId: UUID, date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateKey = String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        return "\(reminderId.uuidString)-\(dateKey)"
    }

    // MARK: - scheduleReminder

    @Test func scheduleReminder_createsDailyRequestsWithDatedIdentifiers() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 9, minute: 30, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        #expect(!center.addedRequests.isEmpty)
        let identifiers = center.addedRequests.map(\.identifier)
        #expect(identifiers.allSatisfy { $0.hasPrefix("\(reminder.id.uuidString)-") })
        #expect(Set(identifiers).count == identifiers.count, "у каждого дня окна должен быть свой уникальный идентификатор")
    }

    @Test func scheduleReminder_usesNonRepeatingCalendarTrigger_withReminderTime() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 14, minute: 45, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        let trigger = center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger
        // Не repeating: каждый день окна — отдельный one-time триггер, чтобы можно было
        // точечно отменить конкретный день, не трогая остальные (см. doc-комментарий scheduleReminder)
        #expect(trigger?.repeats == false)
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

    @Test func scheduleReminder_skipsDaysBeforeCourseStartDate() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 9, minute: 30, isEnabled: true)
        let calendar = Calendar.current
        let futureStart = calendar.date(byAdding: .day, value: 3, to: .now)!
        let course = makeCourse(startDate: futureStart, reminders: [reminder])

        await service.scheduleReminder(for: course, reminder: reminder)

        let scheduledDates = center.addedRequests
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
            .compactMap { calendar.date(from: $0) }

        #expect(!scheduledDates.isEmpty)
        #expect(scheduledDates.allSatisfy { $0 >= calendar.startOfDay(for: futureStart) })
    }

    @Test func scheduleReminder_skipsPausedDays() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 23, minute: 59, isEnabled: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let pauseStart = calendar.date(byAdding: .day, value: 2, to: today)!
        let pauseEnd = calendar.date(byAdding: .day, value: 4, to: today)!
        let course = makeCourse(startDate: calendar.date(byAdding: .day, value: -1, to: today)!, reminders: [reminder])
        course.pauses = [CoursePause(startDate: pauseStart, endDate: pauseEnd)]

        await service.scheduleReminder(for: course, reminder: reminder)

        let scheduledDays = center.addedRequests
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }

        #expect(scheduledDays.contains(calendar.date(byAdding: .day, value: 1, to: today)!))
        #expect(!scheduledDays.contains(pauseStart))
        #expect(!scheduledDays.contains(calendar.date(byAdding: .day, value: 3, to: today)!))
        #expect(scheduledDays.contains(pauseEnd), "день окончания паузы уже не на паузе")
    }

    @Test func scheduleReminder_openPause_schedulesNothing() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 23, minute: 59, isEnabled: true)
        let course = makeCourse(reminders: [reminder])
        course.pauses = [CoursePause(startDate: Calendar.current.startOfDay(for: .now))]

        await service.scheduleReminder(for: course, reminder: reminder)

        #expect(center.addedRequests.isEmpty)
    }

    // MARK: - scheduleOneTimeReminder (snooze)

    @Test func scheduleOneTimeReminder_usesIdentifierDistinctFromDailyReminder() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 10, minute: 0, isEnabled: true)
        let course = makeCourse(reminders: [reminder])

        // Ежедневные (по одному на день окна) уже запланированы
        await service.scheduleReminder(for: course, reminder: reminder)
        let dailyIdentifiers = Set(center.addedRequests.map(\.identifier))

        // Снус на то же напоминание
        await service.scheduleOneTimeReminder(
            courseId: course.id,
            reminderId: reminder.id,
            originalDate: .now,
            afterInterval: 3600
        )

        let allIdentifiers = center.addedRequests.map(\.identifier)
        #expect(allIdentifiers.count == dailyIdentifiers.count + 1)

        let snoozeIdentifier = allIdentifiers.last
        #expect(snoozeIdentifier == "\(reminder.id.uuidString)-snooze")
        #expect(
            !dailyIdentifiers.contains(snoozeIdentifier ?? ""),
            "identifier снуса должен отличаться от любого ежедневного, иначе add() тихо заменит его триггер"
        )
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

        let removedPending = center.removedPendingIdentifiers.last ?? []
        let removedDelivered = center.removedDeliveredIdentifiers.last ?? []

        // Отменяются: legacy-идентификатор (без даты, от старой схемы), снус,
        // и датированные идентификаторы дней окна — одинаково для pending и delivered
        #expect(removedPending == removedDelivered)
        #expect(removedPending.contains(reminder.id.uuidString))
        #expect(removedPending.contains("\(reminder.id.uuidString)-snooze"))
        #expect(removedPending.contains(dailyIdentifier(for: reminder.id, date: .now)))
    }

    // MARK: - removeNotifications(forCourseId:upTo:)

    private func makeDailyRequest(reminderId: UUID, courseId: UUID, day: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["courseId": courseId.uuidString, "reminderId": reminderId.uuidString]
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = 23
        return UNNotificationRequest(
            identifier: dailyIdentifier(for: reminderId, date: day),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    @Test func removeNotifications_removesDeliveredForIntakeDayAndEarlier_keepsLaterAndOtherCourses() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let calendar = Calendar.current
        let courseId = UUID()
        let reminderId = UUID()
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let otherCourseRequest = makeDailyRequest(reminderId: UUID(), courseId: UUID(), day: twoDaysAgo)
        center.deliveredRequests = [
            makeDailyRequest(reminderId: reminderId, courseId: courseId, day: twoDaysAgo),
            makeDailyRequest(reminderId: reminderId, courseId: courseId, day: yesterday),
            makeDailyRequest(reminderId: reminderId, courseId: courseId, day: today),
            otherCourseRequest
        ]

        await service.removeNotifications(forCourseId: courseId, upTo: yesterday)

        #expect(Set(center.deliveredRequests.map(\.identifier)) == [
            dailyIdentifier(for: reminderId, date: today),
            otherCourseRequest.identifier
        ])
    }

    @Test func removeNotifications_removesDeliveredSnoozeFromEarlierDay() async {
        // Вчерашний snooze уже висит в Notification Center, приём отмечен за сегодня — вчерашний
        // пропущен, уведомление убираем
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let courseId = UUID()
        let reminderId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        await service.scheduleOneTimeReminder(courseId: courseId, reminderId: reminderId, originalDate: yesterday, afterInterval: 3600)
        center.deliveredRequests = center.addedRequests

        await service.removeNotifications(forCourseId: courseId, upTo: .now)

        #expect(center.deliveredRequests.isEmpty)
    }

    @Test func removeNotifications_removesPendingSnoozeForSameOrEarlierDay() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let courseId = UUID()
        let reminderId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let originalDate = Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: yesterday)!
        await service.scheduleOneTimeReminder(courseId: courseId, reminderId: reminderId, originalDate: originalDate, afterInterval: 3600)

        await service.removeNotifications(forCourseId: courseId, upTo: .now)

        #expect(center.request(identifier: "\(reminderId.uuidString)-snooze") == nil)
    }

    @Test func removeNotifications_keepsPendingForLaterDays() async {
        // Отметка вчерашнего приёма не отменяет ни snooze, ни ежедневные напоминания на сегодня и дальше
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 23, minute: 59, isEnabled: true)
        let course = makeCourse(reminders: [reminder])
        await service.scheduleReminder(for: course, reminder: reminder)
        await service.scheduleOneTimeReminder(courseId: course.id, reminderId: reminder.id, originalDate: .now, afterInterval: 3600)
        let pendingBefore = center.addedRequests.map(\.identifier)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        await service.removeNotifications(forCourseId: course.id, upTo: yesterday)

        #expect(center.addedRequests.map(\.identifier) == pendingBefore)
    }

    @Test func removeNotifications_today_removesTodaysPendingDaily_keepsTomorrow() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let reminder = Reminder(hour: 23, minute: 59, isEnabled: true)
        let course = makeCourse(startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, reminders: [reminder])
        await service.scheduleReminder(for: course, reminder: reminder)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!

        await service.removeNotifications(forCourseId: course.id, upTo: .now)

        #expect(center.request(identifier: dailyIdentifier(for: reminder.id, date: .now)) == nil)
        #expect(center.request(identifier: dailyIdentifier(for: reminder.id, date: tomorrow)) != nil)
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
        #expect(category?.identifier == NotificationCategoryIdentifier.medicationReminder)
        let actionIdentifiers = Set(category?.actions.map(\.identifier) ?? [])
        #expect(actionIdentifiers == [
            NotificationActionIdentifier.medicationTaken,
            NotificationActionIdentifier.snoozeOneHour
        ])
    }
}
