//
//  SettingsView.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var showingImporter = false
    @State private var importError: String?

    @Environment(\.dismiss) private var dismiss

    let onAddNewCourse: () -> Void

    init(courseService: CourseManagementServiceProtocol, onAddNewCourse: @escaping () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(courseService: courseService))
        self.onAddNewCourse = onAddNewCourse
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Мои курсы")) {
                    ForEach(viewModel.courses) { course in
                        NavigationLink {
                            CourseSettingsView(viewModel: viewModel.makeCourseSettingsViewModel(for: course))
                        } label: {
                            Text(viewModel.medicationName(for: course))
                        }
                    }
                }

                Section {
                    Button(action: onAddNewCourse) {
                        Label("Добавить новый курс", systemImage: "plus.circle")
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Импортировать курс", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        try viewModel.importCourse(from: url)
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Ошибка импорта", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }
}

#Preview {
    SettingsView(courseService: MockCourseManagementService(withMockData: true), onAddNewCourse: {})
}
