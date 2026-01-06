//
//  MainView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel
    @State private var courseForIntake: Course?
    @State private var isCalendarPresented = false
    @State private var isAddCoursePresented = false
    @State private var isSettingsPresented = false
    
    private let courseService: CourseManagementServiceProtocol

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        _viewModel = State(initialValue: MainViewModel(courseService: courseService))
    }

    var body: some View {
        NavigationStack {
            mainContent
                .background(Color(.systemGroupedBackground))
                .navigationTitle(viewModel.selectedDate.formatted(date: .long, time: .omitted))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Сегодня") {
                            withAnimation {
                                viewModel.goToToday()
                            }
                        }
                        .disabled(viewModel.isToday)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            isCalendarPresented = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isAddCoursePresented = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .sheet(item: $courseForIntake) { course in
            IntakeAddingView(course: course, date: viewModel.selectedDate, courseService: courseService)
        }
        .sheet(isPresented: $isCalendarPresented, onDismiss: {
            viewModel.selectDate(viewModel.selectedDate)
        }) {
            FullCalendarView(
                selectedDate: $viewModel.selectedDate,
                courses: viewModel.courses
            )
        }
        .sheet(isPresented: $isAddCoursePresented) {
            AddCourseView(courseService: courseService)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(courseService: courseService)
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            WeekCalendarView(
                weeks: viewModel.weekDays,
                onDaySelected: { day in
                    viewModel.selectWeekDay(day)
                },
                onWeekChanged: { direction in
                    viewModel.changeWeek(direction: direction)
                }
            )
            
            TabView(selection: $viewModel.selectedPageIndex) {
                ForEach(viewModel.dayPages) { page in
                    dayPageView(for: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    private func dayPageView(for page: DayPageModel) -> some View {
        ScrollView {
            if page.courses.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 12) {
                    ForEach(page.courses) { course in
                        IntakeCardView(
                            course: course,
                            selectedDate: page.date,
                            medication: viewModel.medication(for: course),
                            onTap: {
                                courseForIntake = course
                            },
                            onConfirmIntake: {
                                viewModel.confirmIntake(for: course, on: page.date)
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("Нет активных курсов")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.horizontal)
    }
}

#Preview {
    MainView(courseService: MockCourseManagementService(withMockData: true))
}
