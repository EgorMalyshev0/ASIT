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
    @State private var currentPage: Int = 1
    @State private var isAnimating: Bool = false

    private let calendar = Calendar.current
    
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
    
    var body: some View {
        TabView(selection: $currentPage) {
            WeekRow(
                dates: weekDates(for: -1),
                selectedDate: $selectedDate,
                calendar: calendar
            )
            .tag(0)
            
            WeekRow(
                dates: weekDates(for: 0),
                selectedDate: $selectedDate,
                calendar: calendar
            )
            .tag(1)
            
            WeekRow(
                dates: weekDates(for: 1),
                selectedDate: $selectedDate,
                calendar: calendar
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 76)
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
        
        // Ждём окончания анимации свайпа, потом меняем данные и перецентрируем
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
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .secondary)
            
            Text(dayNumber)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : (isToday ? .orange : .primary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.orange : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday && !isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    WeekCalendarView(
        selectedDate: .constant(.now),
        weekOffset: .constant(0)
    )
    .padding()
}
