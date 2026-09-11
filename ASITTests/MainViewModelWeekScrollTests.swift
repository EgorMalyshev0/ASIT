//
//  MainViewModelWeekScrollTests.swift
//  ASITTests
//

import Testing
import Foundation
@testable import ASIT

@MainActor
struct MainViewModelWeekScrollTests {
    private func makeViewModel() -> MainViewModel {
        MainViewModel(courseService: MockCourseManagementService())
    }

    @Test func daySwipe_crossingSundayToMonday_movesWeekScrollTarget() async throws {
        let calendar = Calendar.current
        let viewModel = makeViewModel()

        // Находим ближайшее воскресенье
        var sunday = calendar.startOfDay(for: Date())
        while calendar.component(.weekday, from: sunday) != 1 {
            sunday = calendar.date(byAdding: .day, value: 1, to: sunday)!
        }
        let monday = calendar.date(byAdding: .day, value: 1, to: sunday)!

        viewModel.selectDate(sunday)
        let weekTargetBefore = viewModel.weekScrollTarget

        // Симулируем долистывание дневного скролла до понедельника
        viewModel.scrollTargetDate = monday

        // weekScrollTarget обновляется на следующем тике run loop
        try await Task.sleep(nanoseconds: 50_000_000)

        let weekTargetAfter = viewModel.weekScrollTarget

        #expect(calendar.isDate(viewModel.selectedDate, inSameDayAs: monday))
        #expect(weekTargetAfter != weekTargetBefore)
    }
}
