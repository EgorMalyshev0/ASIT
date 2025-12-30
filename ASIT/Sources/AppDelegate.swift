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
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
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
        
        if response.actionIdentifier == NotificationService.takenActionIdentifier {
            handleTakenAction(courseId: courseId)
        }
    }
    
    // MARK: - Private
    
    @MainActor
    private func handleTakenAction(courseId: UUID) {
        guard let courseService,
              let course = courseService.courses.first(where: { $0.id == courseId }),
              let lastIntake = course.lastIntake else {
            return
        }
        
        let intake = Intake(
            date: Date(),
            medicationId: course.medicationId,
            packageId: lastIntake.packageId,
            dosage: lastIntake.dosage,
            comment: nil
        )
        
        courseService.addIntake(intake, to: course)
    }
}

