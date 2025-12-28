//
//  MainView.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import SwiftData
import SwiftUI

struct MainView: View {
    @Query var courses: [Course]
    @Environment(\.modelContext) var modelContext
    @State private var viewModel: MainViewModel
    @State private var isCourseAddingPresented: Bool = false

    init() {
        _viewModel = State(initialValue: MainViewModel())
    }

    var body: some View {
        content
            .sheet(isPresented: $isCourseAddingPresented) {
                AddCourseView(modelContext: modelContext)
            }
    }
}

private extension MainView {
    @ViewBuilder
    var content: some View {
        if courses.isEmpty {
            MainEmptyView {
                isCourseAddingPresented = true
            }
        } else {
            VStack {
                ForEach(courses) {
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Course.self, configurations: config)

    MainView()
        .modelContext(container.mainContext)
}
