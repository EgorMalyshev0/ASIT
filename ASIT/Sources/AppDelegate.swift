//
//  AppDelegate.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let courseService = CourseManagementService()
    let localizationService = LocalizationService()
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        Task {
            await NotificationService.shared.requestAuthorization()
        }
        
        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Показывать уведомления даже когда приложение открыто
    /// Не показываем, если на дату уведомления приём уже был
    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        
        guard let courseIdString = userInfo["courseId"] as? String,
              let courseId = UUID(uuidString: courseIdString),
              let course = courseService.courses.first(where: { $0.id == courseId }) else {
            return [.banner, .sound]
        }
        
        // Если на дату уведомления уже был приём — не показываем
        if course.hasIntake(on: notification.date) {
            return []
        }
        
        return [.banner, .sound]
    }
    
    /// Обработка действий из уведомления
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        
        guard let courseIdString = userInfo["courseId"] as? String,
              let courseId = UUID(uuidString: courseIdString) else {
            return
        }
        
        // Дата доставки уведомления — к этому дню относится приём
        let notificationDate = response.notification.date
        
        // Дата для записи приёма: originalDate (если было отложено) или дата доставки
        let intakeDate: Date
        if let timestamp = userInfo["originalDate"] as? TimeInterval {
            intakeDate = Date(timeIntervalSince1970: timestamp)
        } else {
            intakeDate = notificationDate
        }
        
        switch response.actionIdentifier {
        case NotificationService.takenActionIdentifier:
            courseService.handleTakenActionFromPush(courseId: courseId, date: intakeDate)
            
        case NotificationService.snoozeActionIdentifier:
            // Откладываем напоминание на час от текущего времени
            let reminderId = (userInfo["reminderId"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
            await NotificationService.shared.scheduleOneTimeReminder(
                courseId: courseId,
                reminderId: reminderId,
                originalDate: intakeDate,
                afterInterval: 3600 // 1 час
            )
            
        default:
            break
        }
    }
}

