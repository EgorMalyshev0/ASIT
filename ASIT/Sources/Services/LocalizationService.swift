//
//  LocalizationService.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import Foundation
import Combine

final class LocalizationService: ObservableObject {
    @Published var locale: Locale = .current
}
