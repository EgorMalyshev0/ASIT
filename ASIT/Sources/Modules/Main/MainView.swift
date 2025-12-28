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
            VStack {
                ForEach(courseService.courses) {
                    CourseCardView(course: $0, onSelect: {
                        print("Selected course: \($0)")
                    }, onIntake: {
                        print("Intaked course: \($0)")
                    })
                }
            }
            .padding()
        }
    }
}

#Preview {
    MainView()
        .environmentObject(CourseManagementService())
}
