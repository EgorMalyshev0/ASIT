//
//  WeekCalendarView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

/// Горизонтальный календарь недели с возможностью прокрутки по 7 дней
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var weekOffset: Int

    private let calendar = Calendar.current
    
    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let offsetWeekStart = calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStart) else {
            return []
        }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: offsetWeekStart)
        }
    }
    
    private var monthYearTitle: String {
        guard let firstDate = weekDates.first else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: firstDate).capitalized
    }
    
    /// Индекс текущего выбранного дня в неделе (0 = понедельник, 6 = воскресенье)
    private var selectedDayIndex: Int {
        let weekday = calendar.component(.weekday, from: selectedDate)
        // Конвертируем: 1 (вс) -> 6, 2 (пн) -> 0, 3 (вт) -> 1, ...
        return (weekday + 5) % 7
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
        VStack(spacing: 12) {            
            // Дни недели
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
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
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < 0 {
                        // Свайп влево - следующая неделя
                        withAnimation(.easeInOut(duration: 0.2)) {
                            weekOffset += 1
                            selectSameDayInNewWeek()
                        }
                    } else if value.translation.width > 0 {
                        // Свайп вправо - предыдущая неделя
                        withAnimation(.easeInOut(duration: 0.2)) {
                            weekOffset -= 1
                            selectSameDayInNewWeek()
                        }
                    }
                }
        )
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    private let calendar = Calendar.current
    
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

