//
//  ScheduledTimeTests.swift
//  ASITTests
//
//  Created by Egor Malyshev on 16.09.2026.
//

import Testing
import Foundation
@testable import ASIT

struct ScheduledTimeTests {
    private let calendar = Calendar.current

    @Test func initFromDate_extractsHourAndMinute() {
        let moment = calendar.date(bySettingHour: 18, minute: 15, second: 42, of: .now)!

        #expect(ScheduledTime(date: moment, calendar: calendar) == ScheduledTime(hour: 18, minute: 15))
    }

    @Test func dateOnDay_keepsDayAndSetsTime() {
        let day = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: .now))!

        let moment = ScheduledTime(hour: 7, minute: 30).date(on: day, calendar: calendar)

        #expect(moment.map { calendar.isDate($0, inSameDayAs: day) } == true)
        #expect(moment.map { calendar.component(.hour, from: $0) } == 7)
        #expect(moment.map { calendar.component(.minute, from: $0) } == 30)
    }

    @Test func comparable_ordersByHourThenMinute() {
        let morning = ScheduledTime(hour: 9, minute: 55)
        let noon = ScheduledTime(hour: 10, minute: 5)

        #expect(morning < noon)
        #expect(ScheduledTime(hour: 10, minute: 0) < noon)
    }

    @Test func formatted_padsWithZeros() {
        #expect(ScheduledTime(hour: 9, minute: 5).formatted == "09:05")
    }
}
