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

    init(modelContext: ModelContext) {
        let viewModel = ViewModel(modelContext: modelContext)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
    }
}

private extension MainView {
    @ViewBuilder
    var content: some View {
        if viewModel.courses.isEmpty {
            EmptyView()
        } else {
            EmptyView()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Course.self, configurations: config)

    MainView(modelContext: container.mainContext)
}
