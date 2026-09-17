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
    private(set) var scheduledNotifications: [(course: Course, schedule: IntakeSchedule, courseName: String)] = []
    private(set) var canceledNotifications: [IntakeSchedule] = []
    private(set) var removedNotifications: [(courseId: UUID, upToDate: Date)] = []
    private(set) var removedNotificationsOutsideCourse: [(courseId: UUID, startDate: Date, endDate: Date)] = []
    private(set) var scheduledSnoozes: [(courseId: UUID, scheduleId: UUID, courseName: String, originalDate: Date, interval: TimeInterval)] = []
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

    func scheduleNotifications(for course: Course, schedule: IntakeSchedule, courseName: String) async {
        scheduledNotifications.append((course, schedule, courseName))
        callLog.append("schedule:\(schedule.id)")
    }

    func scheduleSnoozeNotification(
        courseId: UUID,
        scheduleId: UUID,
        courseName: String,
        originalDate: Date,
        afterInterval interval: TimeInterval
    ) async {
        scheduledSnoozes.append((courseId, scheduleId, courseName, originalDate, interval))
        callLog.append("scheduleOneTime:\(scheduleId)")
    }

    func cancelNotifications(_ schedule: IntakeSchedule) {
        canceledNotifications.append(schedule)
        callLog.append("cancel:\(schedule.id)")
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
