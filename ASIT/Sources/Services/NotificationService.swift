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
        
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [takenAction],
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
        let status = await checkAuthorizationStatus()

        guard status == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Пора принять лекарство"
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["courseId": course.id.uuidString,
                            "reminderId": reminder.id.uuidString]

        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        
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

