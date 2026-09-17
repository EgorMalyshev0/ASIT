//
//  MainViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import SwiftUI
import Combine

@Observable
final class MainViewModel {
    /// Выбранная дата — единственный источник правды
    var selectedDate: Date

    /// Текущая позиция горизонтального скролла дней (id = дата страницы)
    var scrollTargetDate: Date? {
        didSet {
            guard !isUpdatingFromDateSelection, let scrollTargetDate else {
                return
            }
            handleDayScrollChange(to: scrollTargetDate)
        }
    }

    /// Текущая позиция горизонтального скролла недель (id = дата начала недели)
    var weekScrollTarget: Date? {
        didSet {
            guard !isUpdatingFromDateSelection, let weekScrollTarget else {
                return
            }
            handleWeekScrollChange(to: weekScrollTarget)
        }
    }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    /// Окно страниц дней вокруг selectedDate, расширяется по мере скролла
    private(set) var dayPages: [DayPageModel] = []
    /// Окно страниц недель вокруг selectedDate, расширяется по мере скролла
    private(set) var weekPages: [WeekPageModel] = []
    /// Флаг для предотвращения цикла обновлений между selectedDate и позициями скролла
    private var isUpdatingFromDateSelection = false
    private var cancellables = Set<AnyCancellable>()

    private let calendar = Calendar.current
    private let courseService: CourseManagementServiceProtocol
    private let medicationService: MedicationServiceProtocol

    init(courseService: CourseManagementServiceProtocol, medicationService: MedicationServiceProtocol) {
        self.courseService = courseService
        self.medicationService = medicationService
        let today = calendar.startOfDay(for: Date())
        self.selectedDate = today
        setupBindings()

        rebuildDayPages(around: today)
        rebuildWeekPages(around: today)
        scrollTargetDate = today
        weekScrollTarget = calendar.mondayWeekStart(for: today)
    }

    // MARK: - Public Methods

    func medication(for course: Course) -> Medication? {
        medicationService.medication(withId: course.medicationId)
    }

    func confirmIntake(for course: Course, on date: Date) {
        guard let lastIntake = course.lastIntake else {
            return
        }

        // Вариант и дозировку берём с прошлого приёма, а комментарий - нет: он относился к тому дню
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            variantId: lastIntake.variantId,
            dosage: lastIntake.dosage,
            comment: ""
        )

        courseService.addIntake(intake, to: course)
    }

    func goToToday() {
        selectDate(calendar.startOfDay(for: Date()))
    }

    /// Выбор дня из WeekCalendar
    func selectWeekDay(_ day: WeekDayModel) {
        selectDate(day.date)
    }

    /// Выбор даты (из полного календаря, "Сегодня" или повторный выбор той же даты)
    func selectDate(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)

        // Не выходим раньше времени, даже если normalized уже равен selectedDate:
        // FullCalendarView меняет selectedDate напрямую через Binding, минуя этот
        // метод, а на dismiss мы вызываемся повторно с уже установленной датой —
        // именно тогда и нужно подтянуть окно страниц под неё.
        applySelectedDate(normalized)
        syncScrollTargets()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        courseService.coursesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDayPagesContent()
                self?.refreshWeekPagesContent()
            }
            .store(in: &cancellables)
    }

    /// Пользователь долистал горизонтальный скролл дней до новой страницы
    private func handleDayScrollChange(to date: Date) {
        let normalized = calendar.startOfDay(for: date)
        guard normalized != selectedDate else {
            return
        }

        applySelectedDate(normalized)

        let newWeekStart = calendar.mondayWeekStart(for: normalized)
        guard newWeekStart != weekScrollTarget else {
            return
        }

        // Откладываем на следующий тик: если писать в scrollTarget соседнего
        // ScrollView синхронно изнутри обработчика settle ЭТОГО скролла,
        // SwiftUI иногда тихо игнорирует программный переход .scrollPosition(id:)
        // у другого скролла — неделя визуально не перелистывается, хотя модель
        // уже обновлена корректно.
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.isUpdatingFromDateSelection = true

            withAnimation {
                self.weekScrollTarget = newWeekStart
            }

            self.isUpdatingFromDateSelection = false
        }
    }

    /// Пользователь долистал горизонтальный скролл недель до новой недели
    private func handleWeekScrollChange(to newWeekStart: Date) {
        let currentWeekStart = calendar.mondayWeekStart(for: selectedDate)
        guard !calendar.isDate(newWeekStart, inSameDayAs: currentWeekStart) else {
            return
        }

        // Сохраняем день недели при перелистывании недели целиком. Если этот день
        // недоступен, берём ближайший доступный в новой неделе: newWeekStart уже
        // лежит в [minAllowedWeekStart, maxAllowedWeekStart], поэтому клэмп не
        // выводит дату за пределы новой недели
        let dayOffsetWithinWeek = calendar.dateComponents([.day], from: currentWeekStart, to: selectedDate).day ?? 0
        guard let newDate = calendar.date(byAdding: .day, value: dayOffsetWithinWeek, to: newWeekStart) else {
            return
        }
        let normalized = calendar.startOfDay(for: clampedDate(newDate))
        applySelectedDate(normalized)

        // Откладываем на следующий тик по той же причине, что и в handleDayScrollChange:
        // синхронная запись scrollTargetDate изнутри settle недельного скролла
        // иногда игнорируется, и дневной скролл не перелистывается
        DispatchQueue.main.async { [weak self] in
            guard let self, self.selectedDate == normalized else {
                return
            }

            self.isUpdatingFromDateSelection = true

            withAnimation {
                self.scrollTargetDate = normalized
            }

            self.isUpdatingFromDateSelection = false
        }
    }

    /// Устанавливает selectedDate и подтягивает под неё окна страниц дней и недель,
    /// не трогая позиции скроллов
    private func applySelectedDate(_ date: Date) {
        isUpdatingFromDateSelection = true
        selectedDate = date
        ensureDayWindow(covers: date)
        ensureWeekWindow(covers: date)
        refreshWeekPagesContent()
        isUpdatingFromDateSelection = false
    }

    private func syncScrollTargets() {
        isUpdatingFromDateSelection = true
        scrollTargetDate = selectedDate
        weekScrollTarget = calendar.mondayWeekStart(for: selectedDate)
        isUpdatingFromDateSelection = false
    }

    private func refreshDayPagesContent() {
        guard !dayPages.isEmpty else {
            return
        }
        dayPages = dayPages.map { DayPageModel(date: $0.date, courses: activeCourses(for: $0.date)) }
    }

    private func ensureDayWindow(covers date: Date) {
        let target = clampedDate(calendar.startOfDay(for: date))
        guard let first = dayPages.first?.date, let last = dayPages.last?.date else {
            rebuildDayPages(around: target)
            return
        }

        if target < first || target > last {
            rebuildDayPages(around: target)
            return
        }

        let daysFromStart = calendar.dateComponents([.day], from: first, to: target).day ?? 0
        let daysFromEnd = calendar.dateComponents([.day], from: target, to: last).day ?? 0

        if daysFromStart < Constants.dayWindowExtendThreshold {
            let newPages: [DayPageModel] = (1...Constants.dayWindowExtendChunk).reversed().compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: first).flatMap { candidate in
                    candidate >= minAllowedDate ? DayPageModel(date: candidate, courses: activeCourses(for: candidate)) : nil
                }
            }
            dayPages.insert(contentsOf: newPages, at: 0)
        }

        if daysFromEnd < Constants.dayWindowExtendThreshold {
            let newPages: [DayPageModel] = (1...Constants.dayWindowExtendChunk).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: last).flatMap { candidate in
                    candidate <= maxAllowedDate ? DayPageModel(date: candidate, courses: activeCourses(for: candidate)) : nil
                }
            }
            dayPages.append(contentsOf: newPages)
        }

        trimDayWindow(around: target)
    }

    /// Подрезает окно дней с дальнего от target края, если оно разрослось за счёт
    /// долгого скролла в одну сторону — иначе массив рос бы неограниченно
    private func trimDayWindow(around target: Date) {
        let excess = dayPages.count - Constants.dayWindowMaxSize
        guard excess > 0, let first = dayPages.first?.date, let last = dayPages.last?.date else {
            return
        }

        let daysFromStart = calendar.dateComponents([.day], from: first, to: target).day ?? 0
        let daysFromEnd = calendar.dateComponents([.day], from: target, to: last).day ?? 0

        if daysFromStart > daysFromEnd {
            dayPages.removeFirst(excess)
        } else {
            dayPages.removeLast(excess)
        }
    }

    private func ensureWeekWindow(covers date: Date) {
        let target = clampedWeekStart(calendar.mondayWeekStart(for: date))
        guard let first = weekPages.first?.weekStart, let last = weekPages.last?.weekStart else {
            rebuildWeekPages(around: target)
            return
        }

        if target < first || target > last {
            rebuildWeekPages(around: target)
            return
        }

        let weeksFromStart = (calendar.dateComponents([.day], from: first, to: target).day ?? 0) / 7
        let weeksFromEnd = (calendar.dateComponents([.day], from: target, to: last).day ?? 0) / 7

        if weeksFromStart < Constants.weekWindowExtendThreshold {
            let newPages: [WeekPageModel] = (1...Constants.weekWindowExtendChunk).reversed().compactMap { offset in
                calendar.date(byAdding: .day, value: -offset * 7, to: first).flatMap { candidate in
                    candidate >= minAllowedWeekStart ? makeWeekPageModel(weekStart: candidate) : nil
                }
            }
            weekPages.insert(contentsOf: newPages, at: 0)
        }

        if weeksFromEnd < Constants.weekWindowExtendThreshold {
            let newPages: [WeekPageModel] = (1...Constants.weekWindowExtendChunk).compactMap { offset in
                calendar.date(byAdding: .day, value: offset * 7, to: last).flatMap { candidate in
                    candidate <= maxAllowedWeekStart ? makeWeekPageModel(weekStart: candidate) : nil
                }
            }
            weekPages.append(contentsOf: newPages)
        }

        trimWeekWindow(around: target)
    }

    /// Подрезает окно недель с дальнего от target края — по той же причине,
    /// что и trimDayWindow
    private func trimWeekWindow(around target: Date) {
        let excess = weekPages.count - Constants.weekWindowMaxSize
        guard excess > 0, let first = weekPages.first?.weekStart, let last = weekPages.last?.weekStart else {
            return
        }

        let weeksFromStart = (calendar.dateComponents([.day], from: first, to: target).day ?? 0) / 7
        let weeksFromEnd = (calendar.dateComponents([.day], from: target, to: last).day ?? 0) / 7

        if weeksFromStart > weeksFromEnd {
            weekPages.removeFirst(excess)
        } else {
            weekPages.removeLast(excess)
        }
    }

    private func refreshWeekPagesContent() {
        guard !weekPages.isEmpty else {
            return
        }
        weekPages = weekPages.map { makeWeekPageModel(weekStart: $0.weekStart) }
    }

    private func rebuildDayPages(around date: Date) {
        let center = clampedDate(calendar.startOfDay(for: date))
        let dates = (-Constants.dayWindowRadius...Constants.dayWindowRadius).compactMap {
            calendar.date(byAdding: .day, value: $0, to: center)
        }.filter { $0 >= minAllowedDate && $0 <= maxAllowedDate }
        dayPages = dates.map { DayPageModel(date: $0, courses: activeCourses(for: $0)) }
    }

    private func rebuildWeekPages(around date: Date) {
        let center = clampedWeekStart(calendar.mondayWeekStart(for: date))
        let starts = (-Constants.weekWindowRadius...Constants.weekWindowRadius).compactMap {
            calendar.date(byAdding: .day, value: $0 * 7, to: center)
        }.filter { $0 >= minAllowedWeekStart && $0 <= maxAllowedWeekStart }
        weekPages = starts.map(makeWeekPageModel)
    }

    /// Дата, ограниченная тем же диапазоном, что и основной (полный) календарь
    private func clampedDate(_ date: Date) -> Date {
        min(max(date, minAllowedDate), maxAllowedDate)
    }

    /// Начало недели, ограниченное тем же диапазоном, что и основной (полный) календарь
    private func clampedWeekStart(_ weekStart: Date) -> Date {
        min(max(weekStart, minAllowedWeekStart), maxAllowedWeekStart)
    }

    /// Нижняя и верхняя границы диапазона — та же логика, что и в FullCalendarViewModel,
    /// вынесенная в CourseCalendarRange, чтобы главный, дневной и недельный календари
    /// были ограничены одинаково.
    private var minAllowedDate: Date {
        CourseCalendarRange.minDate(courses: courseService.courses, calendar: calendar)
    }

    private var maxAllowedDate: Date {
        CourseCalendarRange.maxDate(calendar: calendar)
    }

    private var minAllowedWeekStart: Date {
        calendar.mondayWeekStart(for: minAllowedDate)
    }

    private var maxAllowedWeekStart: Date {
        calendar.mondayWeekStart(for: maxAllowedDate)
    }

    private func makeWeekPageModel(weekStart: Date) -> WeekPageModel {
        let days = (0..<7).compactMap { offset -> WeekDayModel? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            return makeWeekDayModel(for: date)
        }
        return WeekPageModel(weekStart: weekStart, days: days)
    }

    private func makeWeekDayModel(for date: Date) -> WeekDayModel {
        let trackableCourses = courseService.trackableCourses(on: date)
        let allTaken = !trackableCourses.isEmpty && trackableCourses.allSatisfy { $0.hasIntake(on: date) }

        let formatter = DateFormatter()
        formatter.dateFormat = "d"

        return WeekDayModel(
            date: date,
            dayNumber: formatter.string(from: date),
            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
            isToday: calendar.isDateInToday(date),
            allIntakesTaken: allTaken,
            hasCourses: !trackableCourses.isEmpty,
            isSelectable: date >= minAllowedDate && date <= maxAllowedDate
        )
    }

    private func activeCourses(for date: Date) -> [Course] {
        courseService.activeCourses(on: date)
    }
}

// MARK: - Constants

private extension MainViewModel {
    enum Constants {
        static let dayWindowRadius = 15
        static let dayWindowExtendThreshold = 5
        static let dayWindowExtendChunk = 15
        /// Верхняя граница размера окна дней — при долгом скролле в одну сторону
        /// не даёт массиву расти неограниченно
        static let dayWindowMaxSize = 90

        static let weekWindowRadius = 2
        static let weekWindowExtendThreshold = 1
        static let weekWindowExtendChunk = 2
        /// Верхняя граница размера окна недель — та же защита, что и dayWindowMaxSize
        static let weekWindowMaxSize = 12
    }
}
