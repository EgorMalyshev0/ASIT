//
//  AppDelegate.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var courseService: CourseManagementService?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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
              let course = courseService?.courses.first(where: { $0.id == courseId }) else {
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
        
        if response.actionIdentifier == NotificationService.takenActionIdentifier {
            handleTakenAction(courseId: courseId, date: notificationDate)
        }
    }
    
    // MARK: - Private
    
    @MainActor
    private func handleTakenAction(courseId: UUID, date: Date) {
        guard let courseService,
              let course = courseService.courses.first(where: { $0.id == courseId }),
              let lastIntake = course.lastIntake else {
            return
        }
        
        // Проверяем, нет ли уже приёма на эту дату
        guard !course.hasIntake(on: date) else {
            return
        }
        
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            packageId: lastIntake.packageId,
            dosage: lastIntake.dosage,
            comment: nil
        )
        
        courseService.addIntake(intake, to: course)
    }
}

