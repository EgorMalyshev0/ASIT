//
//  MockNotificationCenter.swift
//  ASITTests
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Foundation
import UserNotifications
@testable import ASIT

/// Тестовый дабл `NotificationCenterProviding` — хранит запросы/вызовы в памяти вместо обращения
/// к реальному `UNUserNotificationCenter`
final class MockNotificationCenter: NotificationCenterProviding, @unchecked Sendable {
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedPendingIdentifiers: [[String]] = []
    private(set) var removedDeliveredIdentifiers: [[String]] = []
    private(set) var badgeCounts: [Int] = []
    private(set) var setCategories: Set<UNNotificationCategory> = []

    var authorizationStatusToReturn: UNAuthorizationStatus = .authorized
    var deliveredCountToReturn = 0
    var deliveredRequests: [UNNotificationRequest] = []
    var requestAuthorizationResult: Result<Bool, Error> = .success(true)
    var addRequestError: Error?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        switch requestAuthorizationResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusToReturn
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let addRequestError {
            throw addRequestError
        }
        addedRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        addedRequests
    }

    func deliveredNotificationsCount() async -> Int {
        deliveredCountToReturn
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
        addedRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func deliveredNotificationRequests() async -> [UNNotificationRequest] {
        deliveredRequests
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
        deliveredRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func setBadgeCount(_ count: Int) async throws {
        badgeCounts.append(count)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        setCategories = categories
    }

    func request(identifier: String) -> UNNotificationRequest? {
        addedRequests.first { $0.identifier == identifier }
    }
}
