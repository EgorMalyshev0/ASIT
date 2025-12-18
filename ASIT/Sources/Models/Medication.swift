//
//  Medication.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation

struct Medication: Codable {
    let id: String
    let name: LocalizedName
    let therapyType: TherapyType
    var packages: [Package]
}
