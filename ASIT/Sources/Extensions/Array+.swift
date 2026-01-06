//
//  Array+.swift
//  ASIT
//
//  Created by Egor Malyshev on 06.01.2026.
//

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
