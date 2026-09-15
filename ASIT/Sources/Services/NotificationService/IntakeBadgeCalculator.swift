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

    /// Курс ждёт приёма, если последнее напоминание к моменту `date` уже сработало, а приёма на его
    /// день или позже нет. Напоминание срабатывает каждый день курса вне паузы, поэтому последний
    /// такой день — сегодня (если время напоминания уже наступило) или вчера. Завершённый курс,
    /// курс на паузе и курс с выключенным напоминанием приёма не ждут. Считаем по текущему времени
    /// напоминания: если его перенесли после срабатывания, курс может выпасть из бейджа до нового времени
    static func isIntakeOverdue(for course: Course, at date: Date) -> Bool {
        let calendar = Calendar.current
        guard let reminder = course.reminders.first(where: \.isEnabled),
              course.isActive(on: date),
              !course.isPaused(on: date),
              let reminderTime = calendar.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: date) else {
            return false
        }

        let today = calendar.startOfDay(for: date)
        guard let lastReminderDay = reminderTime <= date ? today : calendar.date(byAdding: .day, value: -1, to: today),
              course.isActive(on: lastReminderDay),
              !course.isPaused(on: lastReminderDay) else {
            return false
        }

        return !course.intakes.contains { calendar.startOfDay(for: $0.date) >= lastReminderDay }
    }
}
