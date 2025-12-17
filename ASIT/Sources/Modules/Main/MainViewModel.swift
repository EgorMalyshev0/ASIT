//
//  MainViewModel.swift
//  ASIT
//
//  Created by Egor Malyshev on 17.12.2025.
//

import Foundation
import SwiftData

extension MainView {
    @Observable
    final class ViewModel {
        var modelContext: ModelContext
        var courses = [Course]()

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            fetchData()
        }

        func fetchData() {
            do {
                let descriptor = FetchDescriptor<Course>()
                courses = try modelContext.fetch(descriptor)
            } catch {
                print("Fetch failed")
            }
        }
    }
}
