//
//  MedicationVariant.swift
//  ASIT
//
//  Created by Egor Malyshev on 18.12.2025.
//

import Foundation

extension Medication {
    struct Variant: Codable {
        let id: String
        let name: LocalizedName
        let shortName: LocalizedName
        let administration: Administration
        let dosages: [Dosage]

        init(
            id: String,
            name: LocalizedName,
            shortName: LocalizedName,
            administration: Administration,
            dosages: [Dosage]
        ) {
            self.id = id
            self.name = name
            self.shortName = shortName
            self.administration = administration
            self.dosages = dosages
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case shortName
            case administration
            case dosages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(LocalizedName.self, forKey: .name)
            shortName = try container.decode(LocalizedName.self, forKey: .shortName)
            let decodedAdministration = try container.decode(Administration.self, forKey: .administration)
            administration = decodedAdministration

            dosages = try container.decode([VariantDosage].self, forKey: .dosages).map { dosage in
                Dosage(type: decodedAdministration.type, amount: dosage.amount)
            }
        }
    }

    struct Administration: Codable {
        let type: DosageType
    }

    private struct VariantDosage: Decodable {
        let amount: Int
    }
}
