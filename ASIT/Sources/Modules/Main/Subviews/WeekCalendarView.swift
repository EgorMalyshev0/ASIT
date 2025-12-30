//
//  WeekCalendarView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

/// Горизонтальный календарь недели с paging скроллом
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var weekOffset: Int
    let courses: [Course]
    
    @State private var currentPage: Int = 1
    @State private var isAnimating: Bool = false

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    
    /// Переупорядоченные символы дней недели (начиная с понедельника)
    private var reorderedWeekdays: [String] {
        var symbols = weekdaySymbols
        let sunday = symbols.removeFirst()
        symbols.append(sunday)
        return symbols
    }
    
    /// Индекс текущего выбранного дня в неделе (0 = понедельник, 6 = воскресенье)
    private var selectedDayIndex: Int {
        let weekday = calendar.component(.weekday, from: selectedDate)
        return (weekday + 5) % 7
    }
    
    /// Генерирует даты для недели с указанным offset
    private func weekDates(for offset: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let offsetWeekStart = calendar.date(byAdding: .day, value: (weekOffset + offset) * 7, to: weekStart) else {
            return []
        }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: offsetWeekStart)
        }
    }
    
    /// Выбирает день с тем же индексом в новой неделе
    private func selectSameDayInNewWeek() {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let offsetWeekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStart),
              let newDate = calendar.date(byAdding: .day, value: selectedDayIndex, to: offsetWeekStart) else {
            return
        }
        selectedDate = newDate
    }
    
    /// Проверяет все ли активные курсы на дату имеют приёмы
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Фиксированная строка с днями недели
            HStack(spacing: 0) {
                ForEach(reorderedWeekdays, id: \.self) { symbol in
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
            TabView(selection: $currentPage) {
                WeekRow(
                    dates: weekDates(for: -1),
                    selectedDate: $selectedDate,
                    calendar: calendar,
                    allCoursesHaveIntake: allCoursesHaveIntake
                )
                .tag(0)
                
                WeekRow(
                    dates: weekDates(for: 0),
                    selectedDate: $selectedDate,
                    calendar: calendar,
                    allCoursesHaveIntake: allCoursesHaveIntake
                )
                .tag(1)
                
                WeekRow(
                    dates: weekDates(for: 1),
                    selectedDate: $selectedDate,
                    calendar: calendar,
                    allCoursesHaveIntake: allCoursesHaveIntake
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 56)
//            .padding(.bottom, 8)
        }
//        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .onChange(of: currentPage) { oldValue, newValue in
            handlePageChange(from: oldValue, to: newValue)
        }
    }
    
    private func handlePageChange(from oldValue: Int, to newValue: Int) {
        guard newValue != 1, !isAnimating else { return }
        
        isAnimating = true
        let direction = newValue == 0 ? -1 : 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            weekOffset += direction
            selectSameDayInNewWeek()
            currentPage = 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isAnimating = false
            }
        }
    }
}

// MARK: - WeekRow

private struct WeekRow: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let calendar: Calendar
    let allCoursesHaveIntake: (Date) -> Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    showDot: allCoursesHaveIntake(date)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let showDot: Bool
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayNumber)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
            
            // Точка под числом
            Circle()
                .fill(showDot ? Color.blue : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WeekCalendarView(
        selectedDate: .constant(.now),
        weekOffset: .constant(0),
        courses: []
    )
    .padding()
}
