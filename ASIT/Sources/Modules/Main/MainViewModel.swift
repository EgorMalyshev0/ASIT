//
//  MainViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import Combine

@Observable
final class MainViewModel {
    /// Выбранная дата — единственный источник правды
    var selectedDate: Date {
        didSet {
            selectedDateSubject.send(selectedDate)
        }
    }
    
    /// Индекс выбранной страницы в TabView
    var selectedPageIndex: Int = 10 {
        didSet {
            guard oldValue != selectedPageIndex else { return }
            selectedPageIndexSubject.send(selectedPageIndex)
        }
    }
    
    /// Страницы дней для TabView (21 день)
    private(set) var dayPages: [DayPageModel] = []
    
    /// Дни для WeekCalendarView (3 недели вокруг selectedDate)
    private(set) var weekDays: [[WeekDayModel]] = []
    
    var courses: [Course] = [] {
        didSet { rebuildModels() }
    }
    var medications: [Medication] = []
    
    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private let calendar = Calendar.current
    private let courseService: CourseManagementServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private let selectedDateSubject = PassthroughSubject<Date, Never>()
    private let selectedPageIndexSubject = PassthroughSubject<Int, Never>()
    
    /// Флаг для предотвращения цикла обновлений
    private var isUpdatingFromDateSelection = false

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        self.selectedDate = calendar.startOfDay(for: Date())
        setupBindings()
        fetchMedications()
        rebuildModels()
    }
    
    // MARK: - Public Methods
    
    func medication(for course: Course) -> Medication? {
        medications.first { $0.id == course.medicationId }
    }
    
    func confirmIntake(for course: Course, on date: Date) {
        guard let lastIntake = course.lastIntake else { return }
        
        let intake = Intake(
            date: date,
            medicationId: course.medicationId,
            packageId: lastIntake.packageId,
            dosage: lastIntake.dosage,
            comment: nil
        )
        
        courseService.addIntake(intake, to: course)
    }
    
    func goToToday() {
        selectDate(calendar.startOfDay(for: Date()))
    }
    
    /// Выбор даты (из календаря или WeekCalendar)
    func selectDate(_ date: Date) {
        isUpdatingFromDateSelection = true
        selectedDate = calendar.startOfDay(for: date)
        rebuildModels()
        selectedPageIndex = 10 // центр
        isUpdatingFromDateSelection = false
    }
    
    /// Выбор дня из WeekCalendar
    func selectWeekDay(_ day: WeekDayModel) {
        selectDate(day.date)
    }
    
    /// Смена недели в WeekCalendar (свайп)
    func changeWeek(direction: Int) {
        guard let newDate = calendar.date(byAdding: .day, value: direction * 7, to: selectedDate) else { return }
        // Сохраняем день недели
        let weekday = calendar.component(.weekday, from: selectedDate)
        let newWeekday = calendar.component(.weekday, from: newDate)
        let adjustment = weekday - newWeekday
        guard let adjustedDate = calendar.date(byAdding: .day, value: adjustment, to: newDate) else { return }
        selectDate(adjustedDate)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        courseService.coursesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] courses in
                self?.courses = courses
            }
            .store(in: &cancellables)
        
        // Обработка свайпа страниц
        selectedPageIndexSubject
            .filter { [weak self] _ in !(self?.isUpdatingFromDateSelection ?? false) }
            .sink { [weak self] newIndex in
                self?.handlePageIndexChange(newIndex)
            }
            .store(in: &cancellables)
    }
    
    private func handlePageIndexChange(_ newIndex: Int) {
        guard let page = dayPages[safe: newIndex] else { return }

        selectedDate = page.date
        
        // Пересчитываем если близко к краю
        let needsRebuild = newIndex <= 3 || newIndex >= dayPages.count - 4
        if needsRebuild {
            rebuildModels()
            isUpdatingFromDateSelection = true
            selectedPageIndex = 10
            isUpdatingFromDateSelection = false
        } else {
            // Обновляем weekDays для отображения правильного выделения
            rebuildWeekDays()
        }
    }
    
    private func rebuildModels() {
        rebuildDayPages()
        rebuildWeekDays()
    }
    
    private func rebuildDayPages() {
        // 21 день: 10 до + текущий + 10 после
        let centerDate = calendar.startOfDay(for: selectedDate)
        
        dayPages = (-10...10).enumerated().map { enumIndex, dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: centerDate) ?? centerDate
            let activeCourses = self.activeCourses(for: date)
            return DayPageModel(id: enumIndex, date: date, courses: activeCourses)
        }
    }
    
    private func rebuildWeekDays() {
        // Находим начало недели для selectedDate
        guard let selectedWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) else {
            return
        }
        
        // 3 недели: предыдущая, текущая, следующая
        weekDays = (-1...1).map { weekOffset in
            guard let weekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: selectedWeekStart) else {
                return []
            }
            
            return (0..<7).compactMap { dayOffset -> WeekDayModel? in
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { return nil }
                return makeWeekDayModel(for: date)
            }
        }
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
        return courses.filter { course in
            let startOfCourseStart = calendar.startOfDay(for: course.startDate)
            let startOfCourseEnd = calendar.startOfDay(for: course.endDate)
            
            return startOfDate >= startOfCourseStart &&
                   startOfDate <= startOfCourseEnd &&
                   !course.isCompleted &&
                   !course.isPaused
        }
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
}
