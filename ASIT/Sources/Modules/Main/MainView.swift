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
            Text("Курсы есть, количество: \(courses.count)")
        }
    }
}

struct MainEmptyView: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("У вас нет ни одного курса")
                .font(.title)
                .foregroundStyle(.primary)

            if #available(iOS 26.0, *) {
                addButton
                    .buttonStyle(.glassProminent)
            } else {
                addButton
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var addButton: some View {
        Button("Добавить", action: onTap)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Course.self, configurations: config)

    MainView()
}
