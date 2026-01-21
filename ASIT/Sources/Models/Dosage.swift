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
        let key: String
        switch type {
        case .press:
            key = "dosage.press"
        case .tablet:
            key = "dosage.tablet"
        }
        return String(format: NSLocalizedString(key, comment: ""), amount)
    }
}
