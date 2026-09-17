//
//  NotificationServiceTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Testing
import UserNotifications
import Foundation
@testable import ASIT

@MainActor
struct NotificationServiceTests {
    private func makeCourse(startDate: Date = .now, schedules: [IntakeSchedule] = []) -> Course {
        let course = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: startDate,
            endDate: .now.addingTimeInterval(60 * 24 * 60 * 60)
        )
        course.schedules = schedules
        return course
    }

    /// Повторяет форматирование идентификатора конкретного дня окна из NotificationService —
    /// сама реализация приватна, поэтому дублируем формат здесь, чтобы независимо проверить контракт
    private func dailyIdentifier(for scheduleId: UUID, date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateKey = String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        return "\(scheduleId.uuidString)-\(dateKey)"
    }

    // MARK: - scheduleReminder

    @Test func scheduleReminder_createsDailyRequestsWithDatedIdentifiers() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 9, minute: 30, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        #expect(!center.addedRequests.isEmpty)
        let identifiers = center.addedRequests.map(\.identifier)
        #expect(identifiers.allSatisfy { $0.hasPrefix("\(schedule.id.uuidString)-") })
        #expect(Set(identifiers).count == identifiers.count, "у каждого дня окна должен быть свой уникальный идентификатор")
    }

    @Test func scheduleReminder_usesNonRepeatingCalendarTrigger_withReminderTime() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 14, minute: 45, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        let trigger = center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger
        // Не repeating: каждый день окна — отдельный one-time триггер, чтобы можно было
        // точечно отменить конкретный день, не трогая остальные (см. doc-комментарий scheduleReminder)
        #expect(trigger?.repeats == false)
        #expect(trigger?.dateComponents.hour == 14)
        #expect(trigger?.dateComponents.minute == 45)
    }

    @Test func scheduleReminder_setsCourseAndReminderIdInUserInfo() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 10, minute: 0, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        let userInfo = center.addedRequests.first?.content.userInfo
        #expect(userInfo?["courseId"] as? String == course.id.uuidString)
        #expect(userInfo?["scheduleId"] as? String == schedule.id.uuidString)
        #expect(userInfo?["originalDate"] == nil)
    }

    @Test func scheduleReminder_leavesBadgeUnset_untilRefreshBadges() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 10, minute: 0, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        #expect(center.addedRequests.allSatisfy { $0.content.badge == nil })
    }

    @Test func scheduleReminder_skipsDaysBeforeCourseStartDate() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 9, minute: 30, isNotificationEnabled: true)
        let calendar = Calendar.current
        let futureStart = calendar.date(byAdding: .day, value: 3, to: .now)!
        let course = makeCourse(startDate: futureStart, schedules: [schedule])

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        let scheduledDates = center.addedRequests
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
            .compactMap { calendar.date(from: $0) }

        #expect(!scheduledDates.isEmpty)
        #expect(scheduledDates.allSatisfy { $0 >= calendar.startOfDay(for: futureStart) })
    }

    @Test func scheduleReminder_skipsPausedDays() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 23, minute: 59, isNotificationEnabled: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let pauseStart = calendar.date(byAdding: .day, value: 2, to: today)!
        let pauseEnd = calendar.date(byAdding: .day, value: 4, to: today)!
        let course = makeCourse(startDate: calendar.date(byAdding: .day, value: -1, to: today)!, schedules: [schedule])
        course.pauses = [CoursePause(startDate: pauseStart, endDate: pauseEnd)]

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        let scheduledDays = center.addedRequests
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }

        #expect(scheduledDays.contains(calendar.date(byAdding: .day, value: 1, to: today)!))
        #expect(!scheduledDays.contains(pauseStart))
        #expect(!scheduledDays.contains(calendar.date(byAdding: .day, value: 3, to: today)!))
        #expect(scheduledDays.contains(pauseEnd), "день окончания паузы уже не на паузе")
    }

    @Test func scheduleReminder_openPause_schedulesNothing() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 23, minute: 59, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])
        course.pauses = [CoursePause(startDate: Calendar.current.startOfDay(for: .now))]

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        #expect(center.addedRequests.isEmpty)
    }

    @Test func scheduleReminder_skipsDaysAfterCourseEndDate() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 23, minute: 59, isNotificationEnabled: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!
        let course = makeCourse(startDate: calendar.date(byAdding: .day, value: -1, to: today)!, schedules: [schedule])
        course.endDate = endDate

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        let scheduledDays = center.addedRequests
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }

        #expect(scheduledDays.contains(endDate), "в день окончания курса напоминание ещё нужно")
        #expect(scheduledDays.allSatisfy { $0 <= endDate })
    }

    @Test func scheduleReminder_completedCourse_schedulesNothing() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 23, minute: 59, isNotificationEnabled: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let course = makeCourse(startDate: calendar.date(byAdding: .day, value: -10, to: today)!, schedules: [schedule])
        course.endDate = calendar.date(byAdding: .day, value: -1, to: today)!

        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")

        #expect(center.addedRequests.isEmpty)
    }

    // MARK: - scheduleOneTimeReminder (snooze)

    @Test func scheduleOneTimeReminder_usesIdentifierDistinctFromDailyReminder() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 10, minute: 0, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])

        // Ежедневные (по одному на день окна) уже запланированы
        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")
        let dailyIdentifiers = Set(center.addedRequests.map(\.identifier))

        // Снус на то же напоминание
        await service.scheduleSnoozeNotification(
            courseId: course.id,
            scheduleId: schedule.id,
            courseName: "Курс",
            originalDate: .now,
            afterInterval: 3600
        )

        let allIdentifiers = center.addedRequests.map(\.identifier)
        #expect(allIdentifiers.count == dailyIdentifiers.count + 1)

        let snoozeIdentifier = allIdentifiers.last
        #expect(snoozeIdentifier == "\(schedule.id.uuidString)-snooze")
        #expect(
            !dailyIdentifiers.contains(snoozeIdentifier ?? ""),
            "identifier снуса должен отличаться от любого ежедневного, иначе add() тихо заменит его триггер"
        )
    }

    @Test func scheduleOneTimeReminder_usesNonRepeatingTimeIntervalTrigger() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let scheduleId = UUID()

        await service.scheduleSnoozeNotification(
            courseId: UUID(),
            scheduleId: scheduleId,
            courseName: "Курс",
            originalDate: .now,
            afterInterval: 3600
        )

        let trigger = center.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        #expect(trigger?.repeats == false)
        #expect(trigger?.timeInterval == 3600)
    }

    @Test func scheduleOneTimeReminder_storesOriginalDateInUserInfo() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)

        await service.scheduleSnoozeNotification(
            courseId: UUID(),
            scheduleId: UUID(),
            courseName: "Курс",
            originalDate: originalDate,
            afterInterval: 3600
        )

        let stored = center.addedRequests.first?.content.userInfo["originalDate"] as? TimeInterval
        #expect(stored == originalDate.timeIntervalSince1970)
    }

    // MARK: - cancelReminder

    @Test func cancelReminder_removesBothDailyAndSnoozeIdentifiers_pendingAndDelivered() {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 10, minute: 0, isNotificationEnabled: true)

        service.cancelNotifications(schedule)

        let removedPending = center.removedPendingIdentifiers.last ?? []
        let removedDelivered = center.removedDeliveredIdentifiers.last ?? []

        // Отменяются снус и датированные идентификаторы дней окна — одинаково для pending и delivered
        #expect(removedPending == removedDelivered)
        #expect(removedPending.contains("\(schedule.id.uuidString)-snooze"))
        #expect(removedPending.contains(dailyIdentifier(for: schedule.id, date: .now)))
    }

    // MARK: - removeNotifications(forCourseId:upTo:)

    private func makeDailyRequest(scheduleId: UUID, courseId: UUID, day: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["courseId": courseId.uuidString, "scheduleId": scheduleId.uuidString]
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = 23
        return UNNotificationRequest(
            identifier: dailyIdentifier(for: scheduleId, date: day),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    @Test func removeNotifications_removesDeliveredForIntakeDayAndEarlier_keepsLaterAndOtherCourses() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let calendar = Calendar.current
        let courseId = UUID()
        let scheduleId = UUID()
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let otherCourseRequest = makeDailyRequest(scheduleId: UUID(), courseId: UUID(), day: twoDaysAgo)
        center.deliveredRequests = [
            makeDailyRequest(scheduleId: scheduleId, courseId: courseId, day: twoDaysAgo),
            makeDailyRequest(scheduleId: scheduleId, courseId: courseId, day: yesterday),
            makeDailyRequest(scheduleId: scheduleId, courseId: courseId, day: today),
            otherCourseRequest
        ]

        await service.removeNotifications(forCourseId: courseId, upTo: yesterday)

        #expect(Set(center.deliveredRequests.map(\.identifier)) == [
            dailyIdentifier(for: scheduleId, date: today),
            otherCourseRequest.identifier
        ])
    }

    @Test func removeNotifications_removesDeliveredSnoozeFromEarlierDay() async {
        // Вчерашний snooze уже висит в Notification Center, приём отмечен за сегодня — вчерашний
        // пропущен, уведомление убираем
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let courseId = UUID()
        let scheduleId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        await service.scheduleSnoozeNotification(courseId: courseId, scheduleId: scheduleId, courseName: "Курс", originalDate: yesterday, afterInterval: 3600)
        center.deliveredRequests = center.addedRequests

        await service.removeNotifications(forCourseId: courseId, upTo: .now)

        #expect(center.deliveredRequests.isEmpty)
    }

    @Test func removeNotifications_removesPendingSnoozeForSameOrEarlierDay() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let courseId = UUID()
        let scheduleId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let originalDate = Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: yesterday)!
        await service.scheduleSnoozeNotification(courseId: courseId, scheduleId: scheduleId, courseName: "Курс", originalDate: originalDate, afterInterval: 3600)

        await service.removeNotifications(forCourseId: courseId, upTo: .now)

        #expect(center.request(identifier: "\(scheduleId.uuidString)-snooze") == nil)
    }

    @Test func removeNotifications_keepsPendingForLaterDays() async {
        // Отметка вчерашнего приёма не отменяет ни snooze, ни ежедневные напоминания на сегодня и дальше
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 23, minute: 59, isNotificationEnabled: true)
        let course = makeCourse(schedules: [schedule])
        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")
        await service.scheduleSnoozeNotification(courseId: course.id, scheduleId: schedule.id, courseName: "Курс", originalDate: .now, afterInterval: 3600)
        let pendingBefore = center.addedRequests.map(\.identifier)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        await service.removeNotifications(forCourseId: course.id, upTo: yesterday)

        #expect(center.addedRequests.map(\.identifier) == pendingBefore)
    }

    @Test func removeNotifications_today_removesTodaysPendingDaily_keepsTomorrow() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 23, minute: 59, isNotificationEnabled: true)
        let course = makeCourse(startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, schedules: [schedule])
        await service.scheduleNotifications(for: course, schedule: schedule, courseName: "Курс")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!

        await service.removeNotifications(forCourseId: course.id, upTo: .now)

        #expect(center.request(identifier: dailyIdentifier(for: schedule.id, date: .now)) == nil)
        #expect(center.request(identifier: dailyIdentifier(for: schedule.id, date: tomorrow)) != nil)
    }

    // MARK: - removeNotifications(forCourseId:outsideOf:)

    @Test func removeNotificationsOutside_removesDaysBeforeStartAndAfterEnd_keepsInsideAndOtherCourses() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let calendar = Calendar.current
        let courseId = UUID()
        let scheduleId = UUID()
        let today = calendar.startOfDay(for: .now)
        let days = (-2...3).map { calendar.date(byAdding: .day, value: $0, to: today)! }
        let otherCourseRequest = makeDailyRequest(scheduleId: UUID(), courseId: UUID(), day: days[0])
        center.deliveredRequests = days.prefix(3).map { makeDailyRequest(scheduleId: scheduleId, courseId: courseId, day: $0) } + [otherCourseRequest]
        for day in days.suffix(3) {
            try? await center.add(makeDailyRequest(scheduleId: scheduleId, courseId: courseId, day: day))
        }

        // Курс теперь со вчера по завтра
        await service.removeNotifications(forCourseId: courseId, outsideOf: days[1], days[3])

        #expect(Set(center.deliveredRequests.map(\.identifier)) == [
            dailyIdentifier(for: scheduleId, date: days[1]),
            dailyIdentifier(for: scheduleId, date: days[2]),
            otherCourseRequest.identifier
        ])
        #expect(center.request(identifier: dailyIdentifier(for: scheduleId, date: days[3])) != nil)
        #expect(center.request(identifier: dailyIdentifier(for: scheduleId, date: days[4])) == nil)
        #expect(center.request(identifier: dailyIdentifier(for: scheduleId, date: days[5])) == nil)
    }

    @Test func removeNotificationsOutside_removesSnoozeForDayAfterNewEnd() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let courseId = UUID()
        let scheduleId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        await service.scheduleSnoozeNotification(courseId: courseId, scheduleId: scheduleId, courseName: "Курс", originalDate: .now, afterInterval: 3600)

        await service.removeNotifications(forCourseId: courseId, outsideOf: yesterday.addingTimeInterval(-86400 * 5), yesterday)

        #expect(center.request(identifier: "\(scheduleId.uuidString)-snooze") == nil)
    }

    // MARK: - Authorization

    @Test func requestAuthorization_returnsCenterResult() async {
        let center = MockNotificationCenter()
        center.requestAuthorizationResult = .success(true)
        let service = NotificationService(notificationCenter: center)

        #expect(await service.requestAuthorization() == true)
    }

    @Test func requestAuthorization_returnsFalse_whenCenterThrows() async {
        struct SomeError: Error {}
        let center = MockNotificationCenter()
        center.requestAuthorizationResult = .failure(SomeError())
        let service = NotificationService(notificationCenter: center)

        #expect(await service.requestAuthorization() == false)
    }

    @Test func checkAuthorizationStatus_reflectsUnderlyingCenter() async {
        let center = MockNotificationCenter()
        center.authorizationStatusToReturn = .denied
        let service = NotificationService(notificationCenter: center)

        #expect(await service.checkAuthorizationStatus() == .denied)
    }

    // MARK: - Badge

    private func day(_ offset: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
    }

    @Test func refreshBadges_setsCurrentBadgeToOverdueCourseCount() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        // Напоминание в 00:00 к текущему моменту уже сработало
        let overdue = makeCourse(startDate: day(-1), schedules: [IntakeSchedule(hour: 0, minute: 0, isNotificationEnabled: true)])
        let disabled = makeCourse(startDate: day(-1), schedules: [IntakeSchedule(hour: 0, minute: 0, isNotificationEnabled: false)])

        await service.refreshBadges(for: [overdue, disabled])

        #expect(center.badgeCounts == [1])
    }

    @Test func refreshBadges_setsPendingBadgeToOverdueCountAtFireTime() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let morningReminder = IntakeSchedule(hour: 10, minute: 0, isNotificationEnabled: true)
        let eveningReminder = IntakeSchedule(hour: 20, minute: 0, isNotificationEnabled: true)
        let morning = makeCourse(startDate: day(1), schedules: [morningReminder])
        let evening = makeCourse(startDate: day(1), schedules: [eveningReminder])
        await service.scheduleNotifications(for: morning, schedule: morningReminder, courseName: "Курс")
        await service.scheduleNotifications(for: evening, schedule: eveningReminder, courseName: "Курс")

        await service.refreshBadges(for: [morning, evening])

        func badge(_ schedule: IntakeSchedule, _ offset: Int) -> Int? {
            center.request(identifier: dailyIdentifier(for: schedule.id, date: day(offset)))?.content.badge as? Int
        }
        #expect(badge(morningReminder, 1) == 1, "к первому утреннему пушу вечерний курс ещё не должен")
        #expect(badge(eveningReminder, 1) == 2)
        #expect(badge(morningReminder, 2) == 2, "пропущенный вчера курс остаётся в бейдже")
    }

    @Test func refreshBadges_snooze_recreatesIntervalTriggerForRemainingTime() async {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        let schedule = IntakeSchedule(hour: 0, minute: 0, isNotificationEnabled: true)
        let course = makeCourse(startDate: day(-1), schedules: [schedule])
        await service.scheduleSnoozeNotification(courseId: course.id, scheduleId: schedule.id, courseName: "Курс", originalDate: .now, afterInterval: 3600)

        await service.refreshBadges(for: [course])

        let request = center.request(identifier: "\(schedule.id.uuidString)-snooze")
        let trigger = request?.trigger as? UNTimeIntervalNotificationTrigger
        #expect(request?.content.badge as? Int == 1)
        #expect((trigger?.timeInterval ?? 0) <= 3600)
        #expect((trigger?.timeInterval ?? 0) > 3500)
        #expect(request?.content.userInfo["fireDate"] != nil)
    }

    // MARK: - Setup

    @Test func init_registersCategoryWithTakenAndSnoozeActions() {
        let center = MockNotificationCenter()
        let service = NotificationService(notificationCenter: center)
        _ = service

        let category = center.setCategories.first
        #expect(center.setCategories.count == 1)
        #expect(category?.identifier == NotificationCategoryIdentifier.medicationReminder)
        let actionIdentifiers = Set(category?.actions.map(\.identifier) ?? [])
        #expect(actionIdentifiers == [
            NotificationActionIdentifier.medicationTaken,
            NotificationActionIdentifier.snoozeOneHour
        ])
    }
}
