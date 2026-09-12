//
//  FullCalendarView.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import SwiftUI

struct FullCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FullCalendarViewModel

    @Binding var selectedDate: Date

    init(selectedDate: Binding<Date>, courseService: CourseManagementServiceProtocol) {
        self._selectedDate = selectedDate
        self._viewModel = State(initialValue: FullCalendarViewModel(courseService: courseService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Фиксированные заголовки дней недели
                HStack(spacing: 4) {
                    ForEach(Calendar.current.mondayFirstShortWeekdaySymbols, id: \.self) { symbol in
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
                            ForEach(viewModel.months, id: \.self) { month in
                                MonthView(
                                    month: month,
                                    selectedDate: selectedDate,
                                    viewModel: viewModel,
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
                        let calendar = Calendar.current
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
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarActionButton(role: .close) {
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
    let viewModel: FullCalendarViewModel
    let onDateSelected: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(viewModel.daysInMonth(for: month).enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isDisabled: date < viewModel.minDate || date > viewModel.maxDate,
                            showDot: viewModel.allCoursesHaveIntake(on: date)
                        )
                        .onTapGesture {
                            if date >= viewModel.minDate && date <= viewModel.maxDate {
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
        courseService: MockCourseManagementService(withMockData: true)
    )
}
