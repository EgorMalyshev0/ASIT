//
//  NotificationService.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import UserNotifications

final class NotificationService: NotificationServiceProtocol {
    private let notificationCenter: NotificationCenterProviding

    init(notificationCenter: NotificationCenterProviding = UNUserNotificationCenter.current()) {
        self.notificationCenter = notificationCenter
        setupNotificationCategory()
    }

    // MARK: - Setup

    private func setupNotificationCategory() {
        let takenAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.medicationTaken,
            title: "Принял",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.snoozeOneHour,
            title: "Отложить на час",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.medicationReminder,
            actions: [takenAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Permissions

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.authorizationStatus()
    }

    // MARK: - Schedule Notifications

    /// Создаёт ежедневное напоминание для курса
    func scheduleReminder(for course: Course, reminder: Reminder) async {
        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let content = await makeNotificationContent(courseId: course.id, reminderId: reminder.id)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)

        await addNotificationRequest(request)
    }

    /// Планирует одноразовое уведомление через указанный интервал (для snooze)
    func scheduleOneTimeReminder(
        courseId: UUID,
        reminderId: UUID,
        originalDate: Date,
        afterInterval interval: TimeInterval
    ) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let content = await makeNotificationContent(
            courseId: courseId,
            reminderId: reminderId,
            originalDate: originalDate
        )
        // Отдельный идентификатор, отличный от ежедневного напоминания
        let request = UNNotificationRequest(
            identifier: snoozeIdentifier(for: reminderId),
            content: content,
            trigger: trigger
        )

        await addNotificationRequest(request)
    }

    // MARK: - Private Helpers

    private func makeNotificationContent(
        courseId: UUID,
        reminderId: UUID,
        originalDate: Date? = nil
    ) async -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Пора принять лекарство"
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder
        // content.badge задаёт абсолютное значение бейджа на момент доставки, а не дельту —
        // системе его инкрементировать не за что. Берём текущее число уже доставленных
        // уведомлений и прибавляем это, чтобы бейдж не сбрасывался в 1 при каждом уведомлении.
        let deliveredCount = await notificationCenter.deliveredNotificationsCount()
        content.badge = NSNumber(value: deliveredCount + 1)

        var userInfo: [String: Any] = [
            "courseId": courseId.uuidString,
            "reminderId": reminderId.uuidString
        ]
        if let originalDate {
            userInfo["originalDate"] = originalDate.timeIntervalSince1970
        }
        content.userInfo = userInfo

        return content
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async {
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    /// Удаляет напоминание для курса (и ежедневное, и отложенное — если оригинал
    /// отменяется или переносится, любой ожидающий snooze для него тоже должен исчезнуть)
    func cancelReminder(_ reminder: Reminder) {
        let identifiers = [reminder.id.uuidString, snoozeIdentifier(for: reminder.id)]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func snoozeIdentifier(for reminderId: UUID) -> String {
        "\(reminderId.uuidString)-snooze"
    }

    // MARK: - Badge

    /// Обновляет badge на основе доставленных уведомлений
    @MainActor
    func updateBadgeCount() async {
        let count = await notificationCenter.deliveredNotificationsCount()
        try? await notificationCenter.setBadgeCount(count)
    }

    /// Сбрасывает badge
    @MainActor
    func clearBadge() async {
        try? await notificationCenter.setBadgeCount(0)
    }

    // MARK: - Remove Delivered

    /// Удаляет доставленные уведомления для курса (при приёме)
    func removeDeliveredNotifications(for course: Course) {
        let identifiers = course.reminders.flatMap { [$0.id.uuidString, snoozeIdentifier(for: $0.id)] }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
