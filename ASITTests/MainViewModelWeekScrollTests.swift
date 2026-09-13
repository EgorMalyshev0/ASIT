//
//  MainViewModelWeekScrollTests.swift
//  ASITTests
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct MainViewModelWeekScrollTests {
    /// Курс, начавшийся давно, — чтобы нижняя граница календаря не мешала листать в прошлое
    private func makeViewModel(courseService: MockCourseManagementService = MockCourseManagementService()) -> MainViewModel {
        let calendar = Calendar.current
        courseService.addCourse(Course(
            medicationId: "staloral_birch_pollen",
            takingYear: .first,
            startDate: calendar.date(byAdding: .day, value: -400, to: .now)!,
            endDate: calendar.date(byAdding: .day, value: 30, to: .now)!
        ))
        return MainViewModel(courseService: courseService, medicationService: MockMedicationService())
    }

    @Test func daySwipe_crossingMondayToSunday_movesWeekScrollTarget() async throws {
        let calendar = Calendar.current
        let viewModel = makeViewModel()

        // Понедельник прошлой недели и воскресенье перед ним — оба в прошлом
        let monday = calendar.date(byAdding: .day, value: -7, to: calendar.mondayWeekStart(for: Date()))!
        let sunday = calendar.date(byAdding: .day, value: -1, to: monday)!

        viewModel.selectDate(monday)
        let weekTargetBefore = viewModel.weekScrollTarget

        // Симулируем долистывание дневного скролла назад до воскресенья
        viewModel.scrollTargetDate = sunday

        // weekScrollTarget обновляется на следующем тике run loop
        try await Task.sleep(nanoseconds: 50_000_000)

        let weekTargetAfter = viewModel.weekScrollTarget

        #expect(calendar.isDate(viewModel.selectedDate, inSameDayAs: sunday))
        #expect(weekTargetAfter != weekTargetBefore)
    }

    @Test func longUnidirectionalDayScroll_keepsWindowsBounded() {
        let calendar = Calendar.current
        let viewModel = makeViewModel()

        var current = viewModel.selectedDate
        for _ in 0..<200 {
            current = calendar.date(byAdding: .day, value: -1, to: current)!
            viewModel.scrollTargetDate = current
        }

        #expect(viewModel.dayPages.count <= 90)
        #expect(viewModel.weekPages.count <= 12)
        #expect(viewModel.dayPages.contains { calendar.isDate($0.date, inSameDayAs: current) })
    }

    @Test func dayAndWeekWindows_neverExtendBeyondToday() {
        let calendar = Calendar.current
        let viewModel = makeViewModel()
        let today = calendar.startOfDay(for: Date())

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        viewModel.selectDate(tomorrow)

        #expect(viewModel.dayPages.allSatisfy { $0.date <= today })
        #expect(viewModel.weekPages.allSatisfy { $0.weekStart <= calendar.mondayWeekStart(for: today) })
        let futureDays = viewModel.weekPages.flatMap(\.days).filter { $0.date > today }
        #expect(futureDays.allSatisfy { !$0.isSelectable })
    }

    @Test func pausedCourse_staysOnDayPage_butDoesNotCountForWeekMarker() {
        let calendar = Calendar.current
        let courseService = MockCourseManagementService()
        let viewModel = makeViewModel(courseService: courseService)
        let course = courseService.courses[0]
        let today = calendar.startOfDay(for: Date())

        courseService.pauseCourse(course)
        viewModel.selectDate(today)

        let todayPage = viewModel.dayPages.first { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(todayPage?.courses.contains { $0.id == course.id } == true)

        let todayModel = viewModel.weekPages.flatMap(\.days).first { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(todayModel?.hasCourses == false)
        #expect(todayModel?.allIntakesTaken == false)
    }
}
