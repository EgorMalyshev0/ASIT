//
//  SelectionList.swift
//  ASIT
//
//  Created by Egor Malyshev on 19.08.2026.
//

import SwiftUI

struct SelectionList<Item: Identifiable>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let items: [Item]
    @Binding var selection: Item.ID?

    let titleForItem: (Item) -> String

    var body: some View {
        List(items) { item in
            Button {
                selection = item.id
                dismiss()
            } label: {
                HStack {
                    Text(titleForItem(item))

                    Spacer()

                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .opacity(item.id == selection ? 1 : 0)
                }
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle(title)
    }
}
