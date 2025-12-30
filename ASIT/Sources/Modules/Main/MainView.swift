//
//  MainView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel
    @State private var selectedCourse: Course?
    @State private var isIntakeAddingPresented = false
    @State private var courseForIntake: Course?
    
    private let courseService: CourseManagementServiceProtocol

    init(courseService: CourseManagementServiceProtocol) {
        self.courseService = courseService
        _viewModel = State(initialValue: MainViewModel(courseService: courseService))
    }

    var body: some View {
        NavigationStack {
            mainContent
                .background(Color(.systemGroupedBackground))
                .navigationTitle(viewModel.selectedDate.formatted())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Сегодня") {
                            withAnimation {
                                viewModel.goToToday()
                            }
                        }
                        .disabled(viewModel.isToday)
                    }
                }
        }
        .sheet(isPresented: $isIntakeAddingPresented) {
            if let course = courseForIntake {
                IntakeAddingView(course: course, date: viewModel.selectedDate, courseService: courseService)
            }
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
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.activeCoursesForSelectedDate) { course in
                            IntakeCardView(
                                course: course,
                                selectedDate: viewModel.selectedDate,
                                medication: viewModel.medication(for: course),
                                onSelect: { course in
                                    selectedCourse = course
                                },
                                onAddIntake: { course in
                                    courseForIntake = course
                                    isIntakeAddingPresented = true
                                },
                                onConfirmIntake: { course in
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
            
            Text("На эту дату нет запланированных приёмов лекарств")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal)
    }
}

#Preview {
    MainView(courseService: MockCourseManagementService(withMockData: true))
}
