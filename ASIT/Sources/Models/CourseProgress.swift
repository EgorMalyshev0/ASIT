//
//  CourseProgress.swift
//  ASIT
//
//  Created by Egor Malyshev on 13.09.2026.
//

import Foundation

/// Прогресс курса для полосы на экране настроек. Всё считается в днях от начала курса:
/// день 0 — дата начала, сегодняшний день считается уже прошедшим.
struct CourseProgress: Equatable {
    /// Прошедший период паузы
    struct Pause: Equatable, Identifiable {
        /// Дни паузы, обрезанные по границам курса и сегодняшнему дню
        let days: Range<Int>
        /// Первый день паузы
        let startDate: Date
        /// Последний день паузы (включительно); nil — пауза ещё не снята, а курс не завершён
        let lastDate: Date?

        var id: Int {
            days.lowerBound
        }
    }

    enum Stage: Equatable {
        /// Курс начнётся через указанное число дней
        case notStarted(daysUntilStart: Int)
        case inProgress
        case finished
    }

    let startDate: Date
    let endDate: Date
    let totalDays: Int
    /// Число прошедших дней курса, включая сегодняшний и дни паузы
    let elapsedDays: Int
    let stage: Stage
    let pauses: [Pause]
    /// Отрезки подряд идущих прошедших дней без приёма и не на паузе. Сегодняшний день
    /// пропущенным не считается — приём ещё можно отметить
    let missedDays: [Range<Int>]

    var remainingDays: Int {
        totalDays - elapsedDays
    }

    var pausedDaysCount: Int {
        pauses.reduce(0) { $0 + $1.days.count }
    }

    var missedDaysCount: Int {
        missedDays.reduce(0) { $0 + $1.count }
    }

    static let empty = CourseProgress(
        startDate: .distantPast,
        endDate: .distantPast,
        totalDays: 1,
        elapsedDays: 0,
        stage: .finished,
        pauses: [],
        missedDays: []
    )

    private init(
        startDate: Date,
        endDate: Date,
        totalDays: Int,
        elapsedDays: Int,
        stage: Stage,
        pauses: [Pause],
        missedDays: [Range<Int>]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalDays = totalDays
        self.elapsedDays = elapsedDays
        self.stage = stage
        self.pauses = pauses
        self.missedDays = missedDays
    }

    init(course: Course, today: Date = Date(), calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: course.startDate)
        let end = calendar.startOfDay(for: course.endDate)

        func dayIndex(_ date: Date) -> Int {
            calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        }

        let totalDays = max(dayIndex(end) + 1, 1)
        let todayIndex = dayIndex(today)
        let elapsedDays = min(max(todayIndex + 1, 0), totalDays)
        let isFinished = todayIndex >= totalDays

        let pauses = course.pauses
            .compactMap { pause -> Pause? in
                // Не снятая пауза тянется до сегодняшнего дня включительно
                let pauseEnd = pause.endDate.map(dayIndex) ?? elapsedDays
                let lowerBound = max(dayIndex(pause.startDate), 0)
                let upperBound = min(pauseEnd, elapsedDays)
                guard lowerBound < upperBound else {
                    return nil
                }
                return Pause(
                    days: lowerBound..<upperBound,
                    startDate: calendar.startOfDay(for: pause.startDate),
                    // Не снятая пауза у завершённого курса закончилась вместе с ним
                    lastDate: pause.endDate.flatMap { calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: $0)) }
                        ?? (isFinished ? end : nil)
                )
            }
            .sorted { $0.days.lowerBound < $1.days.lowerBound }

        let intakeDays = Set(course.intakes.map { dayIndex($0.date) })
        var missedDays: [Range<Int>] = []
        for day in 0..<min(max(todayIndex, 0), totalDays) {
            guard !intakeDays.contains(day), !pauses.contains(where: { $0.days.contains(day) }) else {
                continue
            }
            if let last = missedDays.last, last.upperBound == day {
                missedDays[missedDays.count - 1] = last.lowerBound..<(day + 1)
            } else {
                missedDays.append(day..<(day + 1))
            }
        }

        let stage: Stage
        if todayIndex < 0 {
            stage = .notStarted(daysUntilStart: -todayIndex)
        } else if !isFinished {
            stage = .inProgress
        } else {
            stage = .finished
        }

        self.init(
            startDate: start,
            endDate: end,
            totalDays: totalDays,
            elapsedDays: elapsedDays,
            stage: stage,
            pauses: pauses,
            missedDays: missedDays
        )
    }
}
