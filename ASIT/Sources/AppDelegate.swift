//
//  AppDelegate.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import UIKit
import UserNotifications
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let serviceProvider = ServiceProvider()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.reminderRefreshTaskIdentifier,
            using: nil
        ) { [serviceProvider] task in
            Self.handleReminderRefresh(task: task as! BGAppRefreshTask, courseService: serviceProvider.courseService)
        }
        scheduleReminderRefresh()

        Task {
            await serviceProvider.notificationService.requestAuthorization()
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleReminderRefresh()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Дешёвая оппортунистическая подстраховка на каждый возврат в foreground — не полагаемся
        // только на BGAppRefreshTask, у которого нет гарантий по времени срабатывания
        serviceProvider.courseService.refreshAllReminderSchedules()
        #if DEBUG
        BGTaskDiagnostics.recordRun(outcome: "foreground-refresh")
        #endif
    }

    private func scheduleReminderRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.reminderRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            BGTaskDiagnostics.recordScheduled(earliestBeginDate: request.earliestBeginDate)
            #endif
        } catch {
            print("Failed to schedule reminder refresh task: \(error)")
        }
    }

    private static func handleReminderRefresh(task: BGAppRefreshTask, courseService: CourseManagementService) {
        // Съедаем запрос сразу — на этот запуск он больше не годится, следующий планируем заново
        scheduleNextReminderRefresh()

        #if DEBUG
        BGTaskDiagnostics.recordRun(outcome: "started")
        #endif

        task.expirationHandler = {
            #if DEBUG
            BGTaskDiagnostics.recordRun(outcome: "expired")
            #endif
            task.setTaskCompleted(success: false)
        }

        let refreshTask = courseService.refreshAllReminderSchedules()

        Task {
            await refreshTask.value
            #if DEBUG
            BGTaskDiagnostics.recordRun(outcome: "success")
            #endif
            task.setTaskCompleted(success: true)
        }
    }

    private static func scheduleNextReminderRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.reminderRefreshTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            BGTaskDiagnostics.recordScheduled(earliestBeginDate: request.earliestBeginDate)
            #endif
        } catch {
            print("Failed to schedule next reminder refresh task: \(error)")
        }
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
              let course = serviceProvider.courseService.courses.first(where: { $0.id == courseId }) else {
            return [.banner, .list, .sound]
        }

        // Если на дату уведомления уже был приём — не показываем
        if course.hasIntake(on: notification.date) {
            return []
        }

        // .list обязателен, иначе баннер, показанный при открытом приложении, не попадёт
        // в Notification Center и будет выглядеть как мгновенно удалённый
        return [.banner, .list, .sound]
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
        case NotificationActionIdentifier.medicationTaken:
            serviceProvider.courseService.handleTakenActionFromPush(courseId: courseId, date: intakeDate)

        case NotificationActionIdentifier.snoozeOneHour:
            // Откладываем напоминание на час от текущего времени.
            guard let reminderIdString = userInfo["reminderId"] as? String,
                  let reminderId = UUID(uuidString: reminderIdString) else {
                return
            }

            // Курс успели поставить на паузу (или удалить) — отложенное напоминание не нужно
            guard let course = serviceProvider.courseService.courses.first(where: { $0.id == courseId }),
                  !course.isPaused else {
                return
            }

            await serviceProvider.notificationService.scheduleOneTimeReminder(
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

private extension AppDelegate {
    enum Constants {
        /// Best-effort подстраховка поверх окна материализованных уведомлений (см.
        /// `NotificationService.reminderWindowDays`): если пользователь долго не открывает
        /// приложение и не взаимодействует с пушами, система может (не гарантированно) запустить
        /// эту задачу и дозаполнить окно дальше.
        static let reminderRefreshTaskIdentifier = "asit.mobile.app.reminderRefresh"
    }
}

