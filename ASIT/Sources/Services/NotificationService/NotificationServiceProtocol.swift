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
    func scheduleNotifications(for course: Course, schedule: IntakeSchedule) async
    func scheduleSnoozeNotification(
        courseId: UUID,
        scheduleId: UUID,
        originalDate: Date,
        afterInterval interval: TimeInterval
    ) async
    func cancelNotifications(_ schedule: IntakeSchedule)
    func removeNotifications(forCourseId courseId: UUID, upTo date: Date) async
    func removeNotifications(forCourseId courseId: UUID, outsideOf startDate: Date, _ endDate: Date) async
    @MainActor func refreshBadges(for courses: [Course]) async
}
