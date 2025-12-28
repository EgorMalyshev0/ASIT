//
//  MainView.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var courseService: CourseManagementService
    @State private var isCourseAddingPresented: Bool = false
    @State private var isCourseSettingsPresented: Bool = false

    var body: some View {
        content
            .sheet(isPresented: $isCourseAddingPresented) {
                AddCourseView(courseService: courseService)
            }
    }
}

private extension MainView {
    @ViewBuilder
    var content: some View {
        if courseService.courses.isEmpty {
            MainEmptyView {
                isCourseAddingPresented = true
            }
        } else {
            NavigationStack {
                VStack {
                    ForEach(courseService.courses) { course in
                        CourseCardView(course: course, onSelect: {
                            isCourseSettingsPresented = true
                            print("Selected course: \($0)")
                        }, onIntake: {
                            print("Intaked course: \($0)")
                        })
                        .navigationDestination(isPresented: $isCourseSettingsPresented) {
                            CourseSettingsView(course: course, courseService: courseService)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(CourseManagementService())
}
