//
//  MainEmptyView.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import SwiftUI

struct MainEmptyView: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("У вас нет ни одного курса")
                .font(.title)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

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
            .font(.title3)
    }
}

#Preview {
    MainEmptyView(onTap: {})
}
