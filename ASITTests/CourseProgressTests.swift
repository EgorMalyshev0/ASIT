//
//  CourseProgressTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 13.09.2026.
//

import Testing
import Foundation
@testable import ASIT

struct CourseProgressTests {
    private let calendar = Calendar.current
    private let start = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start)!
    }

    /// Курс на 10 дней: day(0)...day(9)
    private func makeCourse(pauses: [CoursePause] = [], intakeDays: [Int]? = nil) -> Course {
        let course = Course(medicationId: "staloral_birch_pollen", takingYear: .first, startDate: day(0), endDate: day(9))
        course.pauses = pauses
        // По умолчанию приёмы есть во все дни, чтобы не мешать проверкам пауз
        course.intakes = (intakeDays ?? Array(0..<10)).map {
            Intake(
                date: day($0).addingTimeInterval(9 * 60 * 60),
                medicationId: "staloral_birch_pollen",
                variantId: "staloral_birch_pollen_10_ir_ml",
                dosage: Dosage(type: .press, amount: 1),
                comment: ""
            )
        }
        return course
    }

    private func progress(_ course: Course, today: Int) -> CourseProgress {
        CourseProgress(course: course, today: day(today), calendar: calendar)
    }

    // MARK: - Elapsed / stage

    @Test func elapsedDays_countsTodayAsPassed() {
        let progress = progress(makeCourse(), today: 4)

        #expect(progress.totalDays == 10)
        #expect(progress.elapsedDays == 5)
        #expect(progress.remainingDays == 5)
        #expect(progress.stage == .inProgress)
    }

    @Test func notStarted_reportsDaysUntilStart() {
        let progress = progress(makeCourse(), today: -3)

        #expect(progress.elapsedDays == 0)
        #expect(progress.stage == .notStarted(daysUntilStart: 3))
    }

    @Test func finished_isClampedToCourseBounds() {
        let progress = progress(makeCourse(), today: 20)

        #expect(progress.elapsedDays == 10)
        #expect(progress.remainingDays == 0)
        #expect(progress.stage == .finished)
    }

    @Test func lastDay_isStillInProgress() {
        let progress = progress(makeCourse(), today: 9)

        #expect(progress.remainingDays == 0)
        #expect(progress.stage == .inProgress)
    }

    // MARK: - Pauses

    @Test func finishedPause_isHalfOpenInterval() {
        let course = makeCourse(pauses: [CoursePause(startDate: day(2), endDate: day(4))])

        let progress = progress(course, today: 6)

        #expect(progress.pauses.map(\.days) == [2..<4])
        #expect(progress.pauses.first?.startDate == day(2))
        #expect(progress.pauses.first?.lastDate == day(3))
        #expect(progress.pausedDaysCount == 2)
    }

    @Test func activePause_extendsThroughToday() {
        let course = makeCourse(pauses: [CoursePause(startDate: day(3))])

        let progress = progress(course, today: 5)

        #expect(progress.pauses.map(\.days) == [3..<6])
        #expect(progress.pauses.first?.lastDate == nil)
    }

    @Test func activePause_ofFinishedCourse_endsWithCourse() {
        let course = makeCourse(pauses: [CoursePause(startDate: day(7))])

        let progress = progress(course, today: 15)

        #expect(progress.pauses.map(\.days) == [7..<10])
        #expect(progress.pauses.first?.lastDate == day(9))
    }

    @Test func pauseStartingTomorrow_isNotShown() {
        let course = makeCourse(pauses: [CoursePause(startDate: day(6))])

        #expect(progress(course, today: 5).pauses.isEmpty)
    }

    @Test func pauses_areSortedAndClippedToElapsedTime() {
        let course = makeCourse(pauses: [
            CoursePause(startDate: day(7)),
            CoursePause(startDate: day(1), endDate: day(2))
        ])

        let progress = progress(course, today: 20)

        #expect(progress.pauses.map(\.days) == [1..<2, 7..<10])
    }

    // MARK: - Missed days

    @Test func missedDays_groupsConsecutiveDaysWithoutIntake() {
        let course = makeCourse(intakeDays: [0, 3, 4])

        let progress = progress(course, today: 7)

        // День 7 — сегодня, ещё не пропущен
        #expect(progress.missedDays == [1..<3, 5..<7])
        #expect(progress.missedDaysCount == 4)
    }

    @Test func missedDays_excludePausedDays() {
        let course = makeCourse(pauses: [CoursePause(startDate: day(2), endDate: day(4))], intakeDays: [0])

        let progress = progress(course, today: 6)

        #expect(progress.missedDays == [1..<2, 4..<6])
    }

    @Test func missedDays_areEmptyBeforeStart_andClampedAfterEnd() {
        let course = makeCourse(intakeDays: [])

        #expect(progress(course, today: -2).missedDays.isEmpty)
        #expect(progress(course, today: 0).missedDays.isEmpty)
        #expect(progress(course, today: 30).missedDays == [0..<10])
    }
}
