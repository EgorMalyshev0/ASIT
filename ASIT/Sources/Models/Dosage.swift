//
//  Dosage.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation

struct Dosage: Codable, Hashable {
    let type: DosageType
    let amount: Int
    
    var displayName: String {
        switch type {
        case .press:
            return "\(amount) нажатий"
        case .tablet:
            return "\(amount) таблеток"
        }
    }
}
