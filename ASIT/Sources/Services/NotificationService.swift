//
//  NotificationService.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// Идентификатор действия "Принял"
    static let takenActionIdentifier = "TAKEN_ACTION"
    /// Идентификатор действия "Отложить на час"
    static let snoozeActionIdentifier = "SNOOZE_ONE_HOUR"
    /// Идентификатор категории уведомлений
    static let categoryIdentifier = "MEDICATION_REMINDER"
    
    private init() {
        setupNotificationCategory()
    }
    
    // MARK: - Setup
    
    private func setupNotificationCategory() {
        let takenAction = UNNotificationAction(
            identifier: Self.takenActionIdentifier,
            title: "Принял",
            options: []
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionIdentifier,
            title: "Отложить на час",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
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
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Schedule Notifications
    
    /// Создаёт ежедневное напоминание для курса
    func scheduleReminder(for course: Course, reminder: Reminder) async {
        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let content = makeNotificationContent(courseId: course.id, reminderId: reminder.id)
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
        let content = makeNotificationContent(courseId: courseId, reminderId: reminderId, originalDate: originalDate)
        let request = UNNotificationRequest(identifier: reminderId.uuidString, content: content, trigger: trigger)
        
        await addNotificationRequest(request)
    }
    
    // MARK: - Private Helpers
    
    private func isAuthorized() async -> Bool {
        await checkAuthorizationStatus() == .authorized
    }
    
    private func makeNotificationContent(courseId: UUID, reminderId: UUID, originalDate: Date? = nil) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Пора принять лекарство"
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        
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
    
    /// Удаляет напоминание для курса
    func cancelReminder(_ reminder: Reminder) {
        let identifier = reminder.id.uuidString
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    /// Удаляет все напоминания
    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}

