//
//  DayPageModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 06.01.2026.
//

import Foundation

/// Модель страницы дня для горизонтального скролла.
/// `id` — сама дата, поэтому при расширении окна прокрутки существующие
/// страницы не меняют идентичность и SwiftUI не теряет позицию скролла.
struct DayPageModel: Identifiable {
    let date: Date
    let courses: [Course]

    var id: Date { date }
}
