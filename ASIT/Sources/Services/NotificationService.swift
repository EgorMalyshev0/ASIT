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
            options: [.foreground]
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
        content.userInfo = ["courseId": course.id.uuidString]
        
        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: course),
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
    func cancelReminder(for course: Course) {
        let identifier = notificationIdentifier(for: course)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    /// Удаляет все напоминания
    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    /// Синхронизирует уведомления с актуальным состоянием курсов
    /// Вызывать при запуске приложения
    func syncNotifications(with courses: [Course]) async {
        let status = await checkAuthorizationStatus()
        guard status == .authorized else { return }
        
        for course in courses {
            let shouldHaveNotification = !course.isCompleted &&
                                         !course.isPaused &&
                                         course.endDate > Date() &&
                                         !course.reminders.isEmpty
            
            if shouldHaveNotification, let reminder = course.reminders.first {
                await scheduleReminder(for: course, reminder: reminder)
            } else {
                cancelReminder(for: course)
            }
        }
    }
    
    // MARK: - Private
    
    private func notificationIdentifier(for course: Course) -> String {
        "reminder_\(course.id.uuidString)"
    }
}

