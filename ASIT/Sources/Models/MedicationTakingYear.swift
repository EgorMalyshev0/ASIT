//
//  MedicationTakingYear.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation

enum MedicationTakingYear: Int, Codable {
    case first
    case second
    case third
    case fourth
    case fifth

    var title: String {
        switch self {
        case .first: 
            "Первый год приёма"
        case .second:
            "Второй год приёма"
        case .third:
            "Третий год приёма"
        case .fourth:
            "Четвертый год приёма"
        case .fifth:
            "Пятый год приёма"
        }
    }
}
