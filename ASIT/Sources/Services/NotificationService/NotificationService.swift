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

    /// Материализует окно индивидуальных ежедневных напоминаний для курса (см. `reminderWindowDays`).
    /// Идемпотентен: повторный вызов (например, при дозаполнении окна на возврате в foreground)
    /// просто заменяет pending-запросы с теми же идентификаторами — БЕЗ этого правила метод нельзя
    /// было бы безопасно перевызывать: пересоздание pending-запроса с тем же id, что и уже доставленное
    /// сегодняшнее уведомление, приводит к тому, что iOS убирает его из Notification Center. Поэтому
    /// сегодняшний день пропускается не только когда приём уже был, но и когда время напоминания на
    /// сегодня уже прошло — раз оно либо уже сработало, либо больше не может сработать, трогать его
    /// identifier не нужно.
    func scheduleReminder(for course: Course, reminder: Reminder) async {
        let calendar = Calendar.current
        let now = Date()
        let courseStart = calendar.startOfDay(for: course.startDate)

        for offset in 0..<Constants.reminderWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            // Курс ещё не начался — не присылаем напоминания раньше даты его старта
            if calendar.startOfDay(for: day) < courseStart {
                continue
            }

            // В дни паузы напоминания не присылаем
            if course.isPaused(on: day) {
                continue
            }

            if offset == 0 {
                let reminderTimeToday = calendar.date(
                    bySettingHour: reminder.hour,
                    minute: reminder.minute,
                    second: 0,
                    of: day
                )
                if course.hasIntake(on: day) || (reminderTimeToday.map { $0 <= now } ?? false) {
                    continue
                }
            }

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let content = await makeNotificationContent(courseId: course.id, reminderId: reminder.id)
            let request = UNNotificationRequest(
                identifier: dailyIdentifier(for: reminder.id, date: day),
                content: content,
                trigger: trigger
            )

            await addNotificationRequest(request)
        }
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

    // MARK: - Cancel Today

    /// Отменяет (pending и delivered) только сегодняшнее вхождение напоминания — вызывается при
    /// отметке приёма, не затрагивает уведомления на другие дни окна.
    func cancelTodayOccurrence(for reminder: Reminder, referenceDate: Date) {
        let identifiers = [dailyIdentifier(for: reminder.id, date: referenceDate)]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Private Helpers

    /// Идентификатор для конкретного дня окна: тот же reminder может иметь несколько pending-запросов
    /// одновременно (по одному на каждый день), поэтому дату кодируем прямо в идентификаторе.
    private func dailyIdentifier(for reminderId: UUID, date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let dateKey = String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        return "\(reminderId.uuidString)-\(dateKey)"
    }

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

    /// Полностью удаляет напоминание для курса: все дни текущего окна, отложенный snooze, и
    /// legacy-идентификатор без даты (от старой схемы с одним repeating-триггером — на случай,
    /// если он остался висеть в системе после обновления приложения)
    func cancelReminder(_ reminder: Reminder) {
        let calendar = Calendar.current
        let today = Date()

        var identifiers = [reminder.id.uuidString, snoozeIdentifier(for: reminder.id)]
        // Запас по краям окна — безопасен, removePendingNotificationRequests просто игнорирует
        // несуществующие идентификаторы
        for offset in -3...(Constants.reminderWindowDays * 2) {
            if let day = calendar.date(byAdding: .day, value: offset, to: today) {
                identifiers.append(dailyIdentifier(for: reminder.id, date: day))
            }
        }

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

    /// Удаляет доставленные уведомления для курса (при приёме) — сегодняшнее вхождение каждого
    /// reminder'а плюс snooze
    func removeDeliveredNotifications(for course: Course) {
        let today = Date()
        let identifiers = course.reminders.flatMap { [dailyIdentifier(for: $0.id, date: today), snoozeIdentifier(for: $0.id)] }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

private extension NotificationService {
    enum Constants {
        /// Сколько дней вперёд держим материализованными индивидуальные (неповторяющиеся)
        /// уведомления. Не repeating-триггер — чтобы можно было точечно отменить конкретный день,
        /// когда приём уже состоялся, не трогая остальные дни серии. Недели достаточно, чтобы
        /// BGAppRefreshTask успел сработать хотя бы раз и дозаполнить окно дальше.
        static let reminderWindowDays = 7
    }
}
