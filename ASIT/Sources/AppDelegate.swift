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
        serviceProvider.courseService.refreshAllNotificationSchedules()
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
            print("Failed to schedule schedule refresh task: \(error)")
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

        let refreshTask = courseService.refreshAllNotificationSchedules()

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
            print("Failed to schedule next schedule refresh task: \(error)")
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

        // При открытом приложении content.badge не применяется — пересчитываем бейдж сами
        serviceProvider.courseService.refreshBadges()

        guard let courseIdString = userInfo["courseId"] as? String,
              let courseId = UUID(uuidString: courseIdString),
              let course = serviceProvider.courseService.courses.first(where: { $0.id == courseId }) else {
            return [.banner, .list, .sound]
        }

        // Если на день, для которого уведомление планировалось, уже был приём или этот день
        // оказался вне дат курса (например, их изменили) — не показываем
        let intendedDate = Self.intendedDate(of: notification)
        if course.hasIntake(on: intendedDate) || !course.isActive(on: intendedDate) {
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
        
        // Приём относится к дню, для которого уведомление планировалось изначально, даже если
        // отложенное уведомление пришло уже после полуночи
        let intakeDate = Self.intendedDate(of: response.notification)

        switch response.actionIdentifier {
        case NotificationActionIdentifier.medicationTaken:
            serviceProvider.courseService.handleTakenActionFromPush(courseId: courseId, date: intakeDate)

        case NotificationActionIdentifier.snoozeOneHour:
            // Откладываем напоминание на час от текущего времени.
            guard let scheduleIdString = userInfo["scheduleId"] as? String,
                  let scheduleId = UUID(uuidString: scheduleIdString) else {
                return
            }

            // Курс успели поставить на паузу, удалить или день оказался вне дат курса — отложенное
            // напоминание не нужно. Snooze за последний день курса после полуночи допустим: приём за
            // этот день ещё можно отметить
            guard let course = serviceProvider.courseService.courses.first(where: { $0.id == courseId }),
                  !course.isPaused,
                  course.isActive(on: intakeDate) else {
                return
            }

            await serviceProvider.notificationService.scheduleSnoozeNotification(
                courseId: courseId,
                scheduleId: scheduleId,
                originalDate: intakeDate,
                afterInterval: 3600 // 1 час
            )
            await serviceProvider.courseService.refreshBadges().value

        default:
            break
        }
    }

    /// Дата, для которой уведомление планировалось: originalDate у отложенного (snooze) — он
    /// переносится и при повторном откладывании — или дата доставки у обычного ежедневного.
    /// Snooze в 23:00 доставляется уже в 00:00 следующего дня, но относится к предыдущему.
    private static func intendedDate(of notification: UNNotification) -> Date {
        if let timestamp = notification.request.content.userInfo["originalDate"] as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        return notification.date
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

