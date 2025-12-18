//
//  MedicationPackage.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation

extension Medication {
    struct Package: Codable {
        let id: String
        let name: LocalizedName
        let dosages: [Dosage]
    }
}
