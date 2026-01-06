//
//  WeekDayModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 06.01.2026.
//

import Foundation

/// Модель дня для WeekCalendarView
struct WeekDayModel: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let allIntakesTaken: Bool
    let hasCourses: Bool
}

