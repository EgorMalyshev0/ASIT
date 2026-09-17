//
//  IntakeBadgeCalculatorTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 15.09.2026.
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct IntakeBadgeCalculatorTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int, hour: Int = 0) -> Date {
        let today = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: offset, to: today)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    /// Курс с -10 по +10 день с напоминанием в 10:00
    private func makeCourse(isNotificationEnabled: Bool = true) -> Course {
        let course = Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: day(-10),
            endDate: day(10)
        )
        course.schedules = [IntakeSchedule(hour: 10, minute: 0, isNotificationEnabled: isNotificationEnabled)]
        return course
    }

    private func addIntake(to course: Course, on date: Date) {
        course.intakes.append(
            Intake(
                date: date,
                medicationId: course.medicationId,
                variantId: "staloral_birch_pollen_10_ir_ml",
                dosage: Dosage(type: .press, amount: 1),
                comment: ""
            )
        )
    }

    @Test func firstDay_beforeReminderTime_notOverdue() {
        let course = makeCourse()
        course.startDate = day(0)

        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 9)))
    }

    @Test func afterReminderTime_withoutIntake_overdue() {
        let course = makeCourse()
        addIntake(to: course, on: day(-1, hour: 12))

        #expect(IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 10)))
    }

    @Test func afterReminderTime_withTodayIntake_notOverdue() {
        let course = makeCourse()
        addIntake(to: course, on: day(0, hour: 11))

        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 12)))
    }

    @Test func beforeReminderTime_yesterdayMissed_staysOverdue() {
        let course = makeCourse()
        addIntake(to: course, on: day(-2, hour: 12))

        #expect(IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 9)))
    }

    @Test func beforeReminderTime_yesterdayMissed_todayIntake_notOverdue() {
        let course = makeCourse()
        addIntake(to: course, on: day(0, hour: 8))

        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 9)))
    }

    @Test func disabledReminder_notOverdue() {
        let course = makeCourse(isNotificationEnabled: false)

        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 12)))
    }

    @Test func completedCourse_withMissedLastDay_notOverdue() {
        let course = makeCourse()
        course.endDate = day(-1)

        #expect(IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(-1, hour: 23)))
        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 9)))
    }

    @Test func pausedToday_notOverdue() {
        let course = makeCourse()
        course.pauses = [CoursePause(startDate: day(0))]

        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 12)))
    }

    @Test func yesterdayPaused_beforeTodayReminder_notOverdue() {
        let course = makeCourse()
        course.pauses = [CoursePause(startDate: day(-3), endDate: day(0))]

        #expect(!IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 9)))
        #expect(IntakeBadgeCalculator.isIntakeOverdue(for: course, at: day(0, hour: 10)))
    }

    @Test func overdueCourseCount_countsEachOverdueCourseOnce() {
        let missedSeveralDays = makeCourse()
        let missedToday = makeCourse()
        addIntake(to: missedToday, on: day(-1, hour: 12))
        let taken = makeCourse()
        addIntake(to: taken, on: day(0, hour: 11))

        let count = IntakeBadgeCalculator.overdueCourseCount(
            in: [missedSeveralDays, missedToday, taken],
            at: day(0, hour: 12)
        )

        #expect(count == 2)
    }
}
