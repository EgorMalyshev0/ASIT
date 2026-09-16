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
    func scheduleNotifications(for course: Course, schedule: IntakeSchedule) async {
        let calendar = Calendar.current
        let now = Date()
        let courseStart = calendar.startOfDay(for: course.startDate)
        let courseEnd = calendar.startOfDay(for: course.endDate)

        for offset in 0..<Constants.reminderWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }

            // Курс ещё не начался — не присылаем напоминания раньше даты его старта
            if calendar.startOfDay(for: day) < courseStart {
                continue
            }

            // Курс уже закончился — после даты окончания напоминания не нужны
            if calendar.startOfDay(for: day) > courseEnd {
                break
            }

            // В дни паузы напоминания не присылаем
            if course.isPaused(on: day) {
                continue
            }

            if offset == 0 {
                let intakeTimeToday = schedule.intakeTime(on: day, calendar: calendar)
                if course.hasIntake(on: day) || (intakeTimeToday.map { $0 <= now } ?? false) {
                    continue
                }
            }

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
            dateComponents.hour = schedule.time.hour
            dateComponents.minute = schedule.time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let content = makeNotificationContent(courseId: course.id, scheduleId: schedule.id)
            let request = UNNotificationRequest(
                identifier: dailyIdentifier(for: schedule.id, date: day),
                content: content,
                trigger: trigger
            )

            await addNotificationRequest(request)
        }
    }

    /// Планирует одноразовое уведомление через указанный интервал (для snooze)
    func scheduleSnoozeNotification(
        courseId: UUID,
        scheduleId: UUID,
        originalDate: Date,
        afterInterval interval: TimeInterval
    ) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let content = makeNotificationContent(
            courseId: courseId,
            scheduleId: scheduleId,
            originalDate: originalDate,
            fireDate: Date().addingTimeInterval(interval)
        )
        // Отдельный идентификатор, отличный от ежедневного напоминания
        let request = UNNotificationRequest(
            identifier: snoozeIdentifier(for: scheduleId),
            content: content,
            trigger: trigger
        )

        await addNotificationRequest(request)
    }

    // MARK: - Remove On Intake

    /// Убирает уведомления курса (pending и delivered) на указанный день и все более ранние —
    /// вызывается при отметке приёма. Приём за этот день уже есть, а более ранние дни без приёма
    /// считаются пропущенными: например, если вчерашний snooze ещё не пришёл (или уже висит в
    /// Notification Center), а приём отмечен за сегодня, напоминать про вчера больше не нужно.
    /// Уведомления на более поздние дни не трогаем: отметка вчерашнего приёма не отменяет сегодняшнее.
    func removeNotifications(forCourseId courseId: UUID, upTo date: Date) async {
        let lastDay = Calendar.current.startOfDay(for: date)
        await removeNotifications(forCourseId: courseId) { day in
            day.map { $0 <= lastDay } ?? true
        }
    }

    /// Убирает уведомления курса (pending и delivered) за дни вне [startDate, endDate] —
    /// вызывается при корректировке дат курса
    func removeNotifications(forCourseId courseId: UUID, outsideOf startDate: Date, _ endDate: Date) async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        await removeNotifications(forCourseId: courseId) { day in
            day.map { $0 < start || $0 > end } ?? true
        }
    }

    // MARK: - Private Helpers

    /// Идентификатор для конкретного дня окна: тот же schedule может иметь несколько pending-запросов
    /// одновременно (по одному на каждый день), поэтому дату кодируем прямо в идентификаторе.
    private func dailyIdentifier(for scheduleId: UUID, date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let dateKey = String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        return "\(scheduleId.uuidString)-\(dateKey)"
    }

    /// Убирает pending и delivered уведомления курса, для дня которых `shouldRemove` вернул true.
    /// В `shouldRemove` передаётся начало дня запроса либо nil, если день определить не удалось
    private func removeNotifications(forCourseId courseId: UUID, where shouldRemove: (Date?) -> Bool) async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let pendingIdentifiers = identifiers(of: pendingRequests, courseId: courseId, where: shouldRemove)
        if !pendingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
        }

        let deliveredRequests = await notificationCenter.deliveredNotificationRequests()
        let deliveredIdentifiers = identifiers(of: deliveredRequests, courseId: courseId, where: shouldRemove)
        if !deliveredIdentifiers.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
        }
    }

    private func identifiers(
        of requests: [UNNotificationRequest],
        courseId: UUID,
        where shouldRemove: (Date?) -> Bool
    ) -> [String] {
        let calendar = Calendar.current
        return requests
            .filter { $0.content.userInfo["courseId"] as? String == courseId.uuidString }
            .filter { shouldRemove(scheduledDay(of: $0).map { calendar.startOfDay(for: $0) }) }
            .map(\.identifier)
    }

    /// День, для которого запрос планировался: originalDate у snooze, дата календарного триггера у
    /// ежедневного. nil — если определить не удалось (такой запрос при приёме просто удаляется)
    private func scheduledDay(of request: UNNotificationRequest) -> Date? {
        if let timestamp = request.content.userInfo["originalDate"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
              trigger.dateComponents.year != nil else {
            return nil
        }
        return Calendar.current.date(from: trigger.dateComponents)
    }

    /// badge здесь не задаём (nil — доставка бейдж не меняет): он зависит от всех курсов сразу
    /// и проставляется в `refreshBadges(for:)`, который вызывается после любого планирования
    private func makeNotificationContent(
        courseId: UUID,
        scheduleId: UUID,
        originalDate: Date? = nil,
        fireDate: Date? = nil
    ) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Пора принять лекарство"
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.medicationReminder

        var userInfo: [String: Any] = [
            "courseId": courseId.uuidString,
            "scheduleId": scheduleId.uuidString
        ]
        if let originalDate {
            userInfo["originalDate"] = originalDate.timeIntervalSince1970
        }
        if let fireDate {
            userInfo["fireDate"] = fireDate.timeIntervalSince1970
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

    /// Полностью удаляет напоминание для курса: все дни текущего окна и отложенный snooze
    func cancelNotifications(_ schedule: IntakeSchedule) {
        let calendar = Calendar.current
        let today = Date()

        var identifiers = [snoozeIdentifier(for: schedule.id)]
        // Запас по краям окна — безопасен, removePendingNotificationRequests просто игнорирует
        // несуществующие идентификаторы
        for offset in -3...(Constants.reminderWindowDays * 2) {
            if let day = calendar.date(byAdding: .day, value: offset, to: today) {
                identifiers.append(dailyIdentifier(for: schedule.id, date: day))
            }
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func snoozeIdentifier(for scheduleId: UUID) -> String {
        "\(scheduleId.uuidString)-snooze"
    }

    // MARK: - Badge

    /// Выставляет бейдж на текущий момент и пересчитывает badge во всех pending-уведомлениях (см.
    /// `IntakeBadgeCalculator`). Пока приложение не запущено, бейдж может поменять только доставка
    /// уведомления, а content.badge — абсолютное значение, посчитанное заранее. Оно зависит от
    /// приёмов и настроек всех курсов, поэтому вызывать нужно после любого их изменения.
    @MainActor
    func refreshBadges(for courses: [Course]) async {
        let now = Date()
        try? await notificationCenter.setBadgeCount(IntakeBadgeCalculator.overdueCourseCount(in: courses, at: now))

        for request in await notificationCenter.pendingNotificationRequests() {
            // Запрос, который вот-вот сработает, не пересоздаём: если он успеет доставиться до add,
            // пересоздание с тем же identifier уберёт доставленное уведомление из Notification Center
            guard request.content.userInfo["courseId"] != nil,
                  let fireDate = fireDate(of: request),
                  fireDate > now.addingTimeInterval(Constants.badgeRefreshSafetyInterval) else {
                continue
            }

            let badge = IntakeBadgeCalculator.overdueCourseCount(in: courses, at: fireDate)
            guard (request.content.badge as? Int) != badge,
                  let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
                continue
            }
            content.badge = NSNumber(value: badge)

            // Интервальный триггер отсчитывается от момента add — пересоздаём его на оставшееся время
            let trigger: UNNotificationTrigger? = request.trigger is UNTimeIntervalNotificationTrigger
                ? UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSince(now), repeats: false)
                : request.trigger
            await addNotificationRequest(
                UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            )
        }
    }

    /// Момент срабатывания: сохранённый fireDate у snooze, дата календарного триггера у ежедневного
    private func fireDate(of request: UNNotificationRequest) -> Date? {
        if let timestamp = request.content.userInfo["fireDate"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
              trigger.dateComponents.year != nil else {
            return nil
        }
        return Calendar.current.date(from: trigger.dateComponents)
    }
}

private extension NotificationService {
    enum Constants {
        /// Запросы, до срабатывания которых осталось меньше, при пересчёте бейджа не трогаем
        static let badgeRefreshSafetyInterval: TimeInterval = 5

        /// Сколько дней вперёд держим материализованными индивидуальные (неповторяющиеся)
        /// уведомления. Не repeating-триггер — чтобы можно было точечно отменить конкретный день,
        /// когда приём уже состоялся, не трогая остальные дни серии. Недели достаточно, чтобы
        /// BGAppRefreshTask успел сработать хотя бы раз и дозаполнить окно дальше.
        static let reminderWindowDays = 7
    }
}
