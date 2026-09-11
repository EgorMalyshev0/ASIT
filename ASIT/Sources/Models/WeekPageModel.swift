//
//  WeekPageModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 11.09.2026.
//

import Foundation

/// Модель страницы недели для горизонтального скролла.
/// `id` — дата начала недели, стабильная во времени, поэтому расширение окна
/// прокрутки не сбивает позицию скролла и подсветку выбранного дня.
struct WeekPageModel: Identifiable {
    let weekStart: Date
    let days: [WeekDayModel]

    var id: Date { weekStart }
}
