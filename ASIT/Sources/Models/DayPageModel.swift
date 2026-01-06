//
//  DayPageModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 06.01.2026.
//

import Foundation

/// Модель страницы дня для TabView
struct DayPageModel: Identifiable, Equatable {
    let id: Int // индекс в массиве
    let date: Date
    let courses: [Course]
    
    static func == (lhs: DayPageModel, rhs: DayPageModel) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date
    }
}

