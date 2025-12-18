//
//  AddCourseView.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import SwiftUI

struct AddCourseView: View {
    @State private var viewModel: AddCourseViewModel

    init() {
        _viewModel = State(initialValue: AddCourseViewModel())
    }

    var body: some View {
        VStack {
            Text("Добавить новый курс")
                .font(.title2)
                .foregroundStyle(.primary)
                .padding()
        }
    }
}

#Preview {
    AddCourseView()
}
