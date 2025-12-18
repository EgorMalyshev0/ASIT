//
//  MainView.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import SwiftData
import SwiftUI

struct MainView: View {
    @State private var viewModel: ViewModel
    @State private var isCourseAddingPresented: Bool = false

    init(modelContext: ModelContext) {
        let viewModel = ViewModel(modelContext: modelContext)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .sheet(isPresented: $isCourseAddingPresented) {
                Text("Hello")
            }
    }
}

private extension MainView {
    @ViewBuilder
    var content: some View {
        if viewModel.courses.isEmpty {
            MainEmptyView {
                isCourseAddingPresented = true
            }
        } else {
            EmptyView()
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

    MainView(modelContext: container.mainContext)
}
