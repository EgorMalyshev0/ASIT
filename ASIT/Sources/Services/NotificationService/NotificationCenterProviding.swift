//
//  NotificationCenterProviding.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import UserNotifications

/// Часть API UNUserNotificationCenter, которой пользуется NotificationService — сведена к
/// примитивным типам (String/Int), а не к UNNotification/UNNotificationSettings, у которых нет
/// публичных инициализаторов и которые поэтому нельзя было бы сконструировать в тестовом дабле.
protocol NotificationCenterProviding {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func deliveredNotificationsCount() async -> Int
    func deliveredNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func setBadgeCount(_ count: Int) async throws
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

extension UNUserNotificationCenter: NotificationCenterProviding {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func deliveredNotificationsCount() async -> Int {
        await deliveredNotifications().count
    }

    func deliveredNotificationRequests() async -> [UNNotificationRequest] {
        await deliveredNotifications().map(\.request)
    }
}
