//
//  MedicationServiceProtocol.swift
//  ASIT
//
//  Created by Egor Malyshev on 11.09.2026.
//

import Foundation

protocol MedicationServiceProtocol: AnyObject {
    var medications: [Medication] { get }

    func medication(withId id: String) -> Medication?
}
