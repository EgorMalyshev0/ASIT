//
//  WeekCalendarView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

/// Горизонтальный календарь недели с бесконечным скроллом.
/// Позиция скролла привязана к дате начала недели (стабильный id),
/// поэтому расширение окна страниц не приводит к перескокам или фризам.
struct WeekCalendarView: View {
    let weekPages: [WeekPageModel]
    @Binding var scrollTarget: Date?
    let onDaySelected: (WeekDayModel) -> Void

    private let weekdaySymbols: [String] = {
        var symbols = Calendar.current.shortWeekdaySymbols
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Фиксированная строка с днями недели
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Скроллящиеся числа
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(weekPages) { week in
                        WeekRow(days: week.days, onDaySelected: onDaySelected)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollTarget)
            .scrollIndicators(.hidden)
            .frame(height: 56)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - WeekRow

private struct WeekRow: View {
    let days: [WeekDayModel]
    let onDaySelected: (WeekDayModel) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                DayCell(day: day)
                    .onTapGesture {
                        withAnimation {
                            onDaySelected(day)
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let day: WeekDayModel

    var body: some View {
        VStack(spacing: 4) {
            Text(day.dayNumber)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(day.isSelected ? .white : (day.isToday ? .blue : .primary))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(day.isSelected ? Color.blue : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(day.isToday && !day.isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )

            // Точка под числом — все курсы приняты
            Circle()
                .fill(day.allIntakesTaken ? Color.blue : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let today = Date()
    let calendar = Calendar.current

    let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

    let weekPages: [WeekPageModel] = (-1...1).map { weekOffset in
        let start = calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStart)!
        let days = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            return WeekDayModel(
                date: date,
                dayNumber: "\(calendar.component(.day, from: date))",
                isSelected: dayOffset == 3 && weekOffset == 0,
                isToday: calendar.isDateInToday(date),
                allIntakesTaken: dayOffset % 3 == 0,
                hasCourses: true
            )
        }
        return WeekPageModel(weekStart: start, days: days)
    }

    return WeekCalendarView(
        weekPages: weekPages,
        scrollTarget: .constant(weekStart),
        onDaySelected: { _ in }
    )
    .padding()
}
