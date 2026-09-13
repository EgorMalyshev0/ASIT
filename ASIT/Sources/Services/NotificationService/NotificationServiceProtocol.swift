//
//  NotificationServiceProtocol.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import Foundation
import UserNotifications

protocol NotificationServiceProtocol: AnyObject {
    func requestAuthorization() async -> Bool
    func checkAuthorizationStatus() async -> UNAuthorizationStatus
    func scheduleReminder(for course: Course, reminder: Reminder) async
    func scheduleOneTimeReminder(
        courseId: UUID,
        reminderId: UUID,
        originalDate: Date,
        afterInterval interval: TimeInterval
    ) async
    func cancelReminder(_ reminder: Reminder)
    func removeNotifications(forCourseId courseId: UUID, upTo date: Date) async
    @MainActor func updateBadgeCount() async
    @MainActor func clearBadge() async
}
