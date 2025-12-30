//
//  SettingsView.swift
//  ASIT
//
//  Created by Egor Malyshev on 30.12.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    init(courseService: CourseManagementServiceProtocol) {
        _viewModel = State(initialValue: SettingsViewModel(courseService: courseService))
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.courses) { course in
                    Section(header: Text(viewModel.medicationName(for: course))) {
                        Button {
                            // TODO: Логика создания напоминания
                        } label: {
                            Label("Создать напоминание", systemImage: "bell")
                        }
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
        }
    }
}

#Preview {
    SettingsView(courseService: MockCourseManagementService(withMockData: true))
}
