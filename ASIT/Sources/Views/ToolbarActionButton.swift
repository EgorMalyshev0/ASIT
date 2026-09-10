//
//  ToolbarActionButton.swift
//  ASIT
//
//  Created by Egor Malyshev on 10.09.2026.
//

import SwiftUI

enum ToolbarActionRole {
    case cancel
    case close
    case confirm

    var title: String {
        switch self {
        case .cancel:   "Отмена"
        case .close:    "Закрыть"
        case .confirm:  "Сохранить"
        }
    }
}

struct ToolbarActionButton: View {
    let role: ToolbarActionRole
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            switch role {
            case .cancel:
                Button(role: .cancel, action: action)
            case .close:
                Button(role: .close, action: action)
            case .confirm:
                Button(role: .confirm, action: action)
            }
        } else {
            Button(role.title, action: action)
        }
    }
}
