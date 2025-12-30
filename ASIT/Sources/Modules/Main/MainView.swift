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
                }
        }
        .sheet(item: $courseForIntake) { course in
            IntakeAddingView(course: course, date: viewModel.selectedDate, courseService: courseService)
        }
        .sheet(isPresented: $isCalendarPresented, onDismiss: {
            viewModel.updateWeekOffset()
        }) {
            FullCalendarView(
                selectedDate: $viewModel.selectedDate,
                courses: viewModel.courses
            )
        }
        .sheet(isPresented: $isAddCoursePresented) {
            AddCourseView(courseService: courseService)
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            WeekCalendarView(
                selectedDate: $viewModel.selectedDate,
                weekOffset: $viewModel.weekOffset
            )
            
            ScrollView {
                if viewModel.activeCoursesForSelectedDate.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.activeCoursesForSelectedDate) { course in
                            IntakeCardView(
                                course: course,
                                selectedDate: viewModel.selectedDate,
                                medication: viewModel.medication(for: course),
                                onTap: {
                                    courseForIntake = course
                                },
                                onConfirmIntake: {
                                    viewModel.confirmIntake(for: course)
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
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
