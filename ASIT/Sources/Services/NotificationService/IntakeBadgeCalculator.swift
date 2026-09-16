//
//  IntakeBadgeCalculator.swift
//  ASIT
//
//  Created by Egor Malyshev on 15.09.2026.
//

import Foundation

/// Бейдж приложения — число курсов с неподтверждённым приёмом, как непрочитанные чаты: курс
/// попадает в бейдж, когда срабатывает его напоминание, и уходит из него только после отметки
/// приёма. Удаление уведомления из Notification Center на бейдж не влияет.
enum IntakeBadgeCalculator {
    /// Сколько курсов будут ждать приёма в момент `date`, если до него новых приёмов не отметят
    static func overdueCourseCount(in courses: [Course], at date: Date) -> Int {
        courses.filter { isIntakeOverdue(for: $0, at: date) }.count
    }

    /// Курс ждёт приёма, если плановое время последнего приёма к моменту `date` уже прошло, а приёма
    /// на его день или позже нет. Приём запланирован на каждый день курса вне паузы, поэтому последний
    /// такой день — сегодня (если время приёма уже наступило) или вчера. Завершённый курс, курс на
    /// паузе и курс с выключенными уведомлениями в бейдж не попадают. Считаем по текущему времени
    /// приёма: если его перенесли после срабатывания, курс может выпасть из бейджа до нового времени
    static func isIntakeOverdue(for course: Course, at date: Date) -> Bool {
        let calendar = Calendar.current
        guard let schedule = course.schedules.first(where: \.isNotificationEnabled),
              course.isActive(on: date),
              !course.isPaused(on: date),
              let intakeTime = schedule.intakeTime(on: date, calendar: calendar) else {
            return false
        }

        let today = calendar.startOfDay(for: date)
        guard let lastIntakeDay = intakeTime <= date ? today : calendar.date(byAdding: .day, value: -1, to: today),
              course.isActive(on: lastIntakeDay),
              !course.isPaused(on: lastIntakeDay) else {
            return false
        }

        return !course.intakes.contains { calendar.startOfDay(for: $0.date) >= lastIntakeDay }
    }
}
