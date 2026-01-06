//
//  WeekCalendarView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

/// Горизонтальный календарь недели с paging скроллом
struct WeekCalendarView: View {
    let weeks: [[WeekDayModel]]
    let onDaySelected: (WeekDayModel) -> Void
    let onWeekChanged: (Int) -> Void
    
    /// Внутреннее состояние для TabView — всегда центрируется на 1
    @State private var currentPage: Int = 1
    @State private var isAnimating = false

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
            TabView(selection: $currentPage) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    WeekRow(days: week, onDaySelected: onDaySelected)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 56)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .onChange(of: currentPage) { oldValue, newValue in
            handlePageChange(from: oldValue, to: newValue)
        }
        .onChange(of: weeks) {
            // При обновлении weeks извне — сбрасываем на центр
            currentPage = 1
        }
    }
    
    private func handlePageChange(from oldValue: Int, to newValue: Int) {
        // Центральная неделя — индекс 1
        guard newValue != 1, !isAnimating else { return }
        
        isAnimating = true
        let direction = newValue == 0 ? -1 : 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onWeekChanged(direction)
            // currentPage сбросится на 1 через onChange(of: weeks)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isAnimating = false
            }
        }
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
                        withAnimation(.easeInOut(duration: 0.15)) {
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
    
    let weeks: [[WeekDayModel]] = (-1...1).map { weekOffset in
        (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: today)!
            return WeekDayModel(
                date: date,
                dayNumber: "\(calendar.component(.day, from: date))",
                isSelected: dayOffset == 3 && weekOffset == 0,
                isToday: calendar.isDateInToday(date),
                allIntakesTaken: dayOffset % 3 == 0,
                hasCourses: true
            )
        }
    }
    
    return WeekCalendarView(
        weeks: weeks,
        onDaySelected: { _ in },
        onWeekChanged: { _ in }
    )
    .padding()
}
