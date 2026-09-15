//
//  MockNotificationService.swift
//  ASITTests
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Foundation
import UserNotifications
@testable import ASIT

final class MockNotificationService: NotificationServiceProtocol {
    private(set) var scheduledReminders: [(course: Course, reminder: Reminder)] = []
    private(set) var canceledReminders: [Reminder] = []
    private(set) var removedNotifications: [(courseId: UUID, upToDate: Date)] = []
    private(set) var removedNotificationsOutsideCourse: [(courseId: UUID, startDate: Date, endDate: Date)] = []
    private(set) var scheduledOneTimeReminders: [(courseId: UUID, reminderId: UUID, originalDate: Date, interval: TimeInterval)] = []
    private(set) var refreshBadgesCallCount = 0
    /// Порядок вызовов вперемешку — для проверки, что асинхронные операции не переупорядочиваются
    private(set) var callLog: [String] = []

    var authorizationGranted = true

    func requestAuthorization() async -> Bool {
        authorizationGranted
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationGranted ? .authorized : .denied
    }

    func scheduleReminder(for course: Course, reminder: Reminder) async {
        scheduledReminders.append((course, reminder))
        callLog.append("schedule:\(reminder.id)")
    }

    func scheduleOneTimeReminder(
        courseId: UUID,
        reminderId: UUID,
        originalDate: Date,
        afterInterval interval: TimeInterval
    ) async {
        scheduledOneTimeReminders.append((courseId, reminderId, originalDate, interval))
        callLog.append("scheduleOneTime:\(reminderId)")
    }

    func cancelReminder(_ reminder: Reminder) {
        canceledReminders.append(reminder)
        callLog.append("cancel:\(reminder.id)")
    }

    func removeNotifications(forCourseId courseId: UUID, upTo date: Date) async {
        removedNotifications.append((courseId, date))
        callLog.append("removeNotifications:\(courseId)")
    }

    func removeNotifications(forCourseId courseId: UUID, outsideOf startDate: Date, _ endDate: Date) async {
        removedNotificationsOutsideCourse.append((courseId, startDate, endDate))
        callLog.append("removeNotificationsOutside:\(courseId)")
    }

    @MainActor
    func refreshBadges(for courses: [Course]) async {
        refreshBadgesCallCount += 1
        callLog.append("refreshBadges")
    }
}
