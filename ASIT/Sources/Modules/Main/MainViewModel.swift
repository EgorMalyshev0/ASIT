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
    var medications: [Medication] = []

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

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        let today = calendar.startOfDay(for: Date())
        self.selectedDate = today
        setupBindings()
        fetchMedications()

        rebuildDayPages(around: today)
        rebuildWeekPages(around: today)
        scrollTargetDate = today
        weekScrollTarget = weekStart(for: today)
    }

    // MARK: - Public Methods

    func medication(for course: Course) -> Medication? {
        medications.first { $0.id == course.medicationId }
    }

    func confirmIntake(for course: Course, on date: Date) {
        guard let lastIntake = course.lastIntake else {
            return
        }

        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            variantId: lastIntake.variantId,
            dosage: lastIntake.dosage,
            comment: nil
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
        isUpdatingFromDateSelection = true
        selectedDate = normalized
        ensureDayWindow(covers: normalized)
        ensureWeekWindow(covers: normalized)
        refreshWeekPagesContent()
        syncScrollTargets()
        isUpdatingFromDateSelection = false
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

    private func fetchMedications() {
        guard let url = Bundle.main.url(forResource: "Medications", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            medications = try decoder.decode([Medication].self, from: data)
        } catch {
            print("Failed to decode Medications: \(error)")
        }
    }

    /// Пользователь долистал горизонтальный скролл дней до новой страницы
    private func handleDayScrollChange(to date: Date) {
        let normalized = calendar.startOfDay(for: date)
        guard normalized != selectedDate else {
            return
        }

        selectedDate = normalized
        ensureDayWindow(covers: normalized)
        ensureWeekWindow(covers: normalized)
        refreshWeekPagesContent()

        let newWeekStart = weekStart(for: normalized)
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
        let currentWeekStart = weekStart(for: selectedDate)
        guard !calendar.isDate(newWeekStart, inSameDayAs: currentWeekStart) else {
            return
        }

        // Сохраняем день недели при перелистывании недели целиком
        let dayOffsetWithinWeek = calendar.dateComponents([.day], from: currentWeekStart, to: selectedDate).day ?? 0
        guard let newDate = calendar.date(byAdding: .day, value: dayOffsetWithinWeek, to: newWeekStart) else {
            return
        }
        selectDate(newDate)
    }

    private func syncScrollTargets() {
        isUpdatingFromDateSelection = true
        scrollTargetDate = selectedDate
        weekScrollTarget = weekStart(for: selectedDate)
        isUpdatingFromDateSelection = false
    }

    private func refreshDayPagesContent() {
        guard !dayPages.isEmpty else {
            return
        }
        dayPages = dayPages.map { DayPageModel(date: $0.date, courses: activeCourses(for: $0.date)) }
    }

    private func ensureDayWindow(covers date: Date) {
        let target = calendar.startOfDay(for: date)
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
                calendar.date(byAdding: .day, value: -offset, to: first).map {
                    DayPageModel(date: $0, courses: activeCourses(for: $0))
                }
            }
            dayPages.insert(contentsOf: newPages, at: 0)
        }

        if daysFromEnd < Constants.dayWindowExtendThreshold {
            let newPages: [DayPageModel] = (1...Constants.dayWindowExtendChunk).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: last).map {
                    DayPageModel(date: $0, courses: activeCourses(for: $0))
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
        let target = weekStart(for: date)
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
                calendar.date(byAdding: .day, value: -offset * 7, to: first).map(makeWeekPageModel)
            }
            weekPages.insert(contentsOf: newPages, at: 0)
        }

        if weeksFromEnd < Constants.weekWindowExtendThreshold {
            let newPages: [WeekPageModel] = (1...Constants.weekWindowExtendChunk).compactMap { offset in
                calendar.date(byAdding: .day, value: offset * 7, to: last).map(makeWeekPageModel)
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
        let center = calendar.startOfDay(for: date)
        let dates = (-Constants.dayWindowRadius...Constants.dayWindowRadius).compactMap {
            calendar.date(byAdding: .day, value: $0, to: center)
        }
        dayPages = dates.map { DayPageModel(date: $0, courses: activeCourses(for: $0)) }
    }

    private func rebuildWeekPages(around date: Date) {
        let center = weekStart(for: date)
        let starts = (-Constants.weekWindowRadius...Constants.weekWindowRadius).compactMap {
            calendar.date(byAdding: .day, value: $0 * 7, to: center)
        }
        weekPages = starts.map(makeWeekPageModel)
    }

    /// Начало недели (понедельник), независимо от локали устройства.
    /// `yearForWeekOfYear`/`weekOfYear` следуют за `calendar.firstWeekday`, который
    /// в некоторых локалях — воскресенье, а вся остальная вёрстка (шапка недели,
    /// сетка FullCalendarView) жёстко считает неделю начинающейся с понедельника.
    /// Расхождение между ними — причина того, что переход Вс → Пн не всегда
    /// засчитывался как смена недели.
    private func weekStart(for date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay) // 1 = вс, ..., 7 = сб
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
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
        let activeCourses = self.activeCourses(for: date)
        let allTaken = !activeCourses.isEmpty && activeCourses.allSatisfy { $0.hasIntake(on: date) }

        let formatter = DateFormatter()
        formatter.dateFormat = "d"

        return WeekDayModel(
            date: date,
            dayNumber: formatter.string(from: date),
            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
            isToday: calendar.isDateInToday(date),
            allIntakesTaken: allTaken,
            hasCourses: !activeCourses.isEmpty
        )
    }

    private func activeCourses(for date: Date) -> [Course] {
        let startOfDate = calendar.startOfDay(for: date)
        return courseService.courses.filter { course in
            let startOfCourseStart = calendar.startOfDay(for: course.startDate)
            let startOfCourseEnd = calendar.startOfDay(for: course.endDate)

            return startOfDate >= startOfCourseStart &&
                   startOfDate <= startOfCourseEnd &&
                   !course.isCompleted &&
                   !course.isPaused
        }
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
