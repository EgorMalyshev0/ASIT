//
//  FullCalendarView.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import SwiftUI

struct FullCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedDate: Date
    let courses: [Course]
    
    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    
    /// Максимальная дата - конец следующей недели после текущей
    private var maxDate: Date {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let nextWeekEnd = calendar.date(byAdding: .day, value: 13, to: weekStart) else {
            return today
        }
        return nextWeekEnd
    }
    
    /// Генерирует месяцы для отображения (от начала самого раннего курса до maxDate)
    private var months: [Date] {
        let earliestCourseStart = courses.map { $0.startDate }.min() ?? Date()
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliestCourseStart)) ?? earliestCourseStart
        let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: maxDate)) ?? maxDate
        
        var months: [Date] = []
        var current = startMonth
        
        while current <= endMonth {
            months.append(current)
            if let next = calendar.date(byAdding: .month, value: 1, to: current) {
                current = next
            } else {
                break
            }
        }
        
        return months
    }
    
    /// Переупорядоченные символы дней недели (начиная с понедельника)
    private var reorderedWeekdays: [String] {
        var symbols = weekdaySymbols
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Фиксированные заголовки дней недели
                HStack(spacing: 4) {
                    ForEach(reorderedWeekdays, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(months, id: \.self) { month in
                                MonthView(
                                    month: month,
                                    selectedDate: selectedDate,
                                    maxDate: maxDate,
                                    courses: courses,
                                    onDateSelected: { date in
                                        selectedDate = date
                                        dismiss()
                                    }
                                )
                                .id(month)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        if let selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) {
                            proxy.scrollTo(selectedMonth, anchor: .center)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - MonthView

private struct MonthView: View {
    let month: Date
    let selectedDate: Date
    let maxDate: Date
    let courses: [Course]
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month).capitalized
    }
    
    /// Все дни месяца с padding для выравнивания по дням недели
    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.leading, 4)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isDisabled: date > maxDate,
                            showDot: allCoursesHaveIntake(on: date)
                        )
                        .onTapGesture {
                            if date <= maxDate {
                                onDateSelected(date)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 52)
                    }
                }
            }
        }
    }
    
    private func allCoursesHaveIntake(on date: Date) -> Bool {
        let activeCourses = courses.filter { course in
            let startOfDate = calendar.startOfDay(for: date)
            let startOfCourseStart = calendar.startOfDay(for: course.startDate)
            let startOfCourseEnd = calendar.startOfDay(for: course.endDate)
            
            return startOfDate >= startOfCourseStart &&
                   startOfDate <= startOfCourseEnd &&
                   !course.isCompleted &&
                   !course.isPaused
        }
        
        guard !activeCourses.isEmpty else { return false }
        return activeCourses.allSatisfy { $0.hasIntake(on: date) }
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isDisabled: Bool
    let showDot: Bool
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var textColor: Color {
        if isDisabled {
            return .secondary.opacity(0.4)
        }
        if isSelected {
            return .white
        }
        if isToday {
            return .blue
        }
        return .primary
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayNumber)
                .font(.system(size: 18, weight: isToday || isSelected ? .bold : .regular))
                .foregroundStyle(textColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            
            // Точка под числом
            Circle()
                .fill(showDot && !isDisabled ? Color.blue : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }
}

#Preview {
    FullCalendarView(
        selectedDate: .constant(.now),
        courses: [.mock]
    )
}
