//
//  BGTaskDiagnostics.swift
//  ASIT
//
//  Created by Egor Malyshev on 12.09.2026.
//

#if DEBUG
import Foundation

/// Хранит историю запусков BGAppRefreshTask в UserDefaults — только для ручного тестирования
/// расписания уведомлений на реальном устройстве в течение нескольких дней. В Release не собирается.
enum BGTaskDiagnostics {
    struct Run: Codable, Identifiable {
        var id: Date { firedAt }
        let firedAt: Date
        let outcome: String
    }

    static func recordRun(outcome: String, at date: Date = Date()) {
        var runs = history
        runs.insert(Run(firedAt: date, outcome: outcome), at: 0)
        if runs.count > Constants.maxHistoryEntries {
            runs.removeLast(runs.count - Constants.maxHistoryEntries)
        }
        if let data = try? JSONEncoder().encode(runs) {
            UserDefaults.standard.set(data, forKey: Constants.historyKey)
        }
    }

    static var history: [Run] {
        guard let data = UserDefaults.standard.data(forKey: Constants.historyKey),
              let runs = try? JSONDecoder().decode([Run].self, from: data) else {
            return []
        }
        return runs
    }

    static func recordScheduled(earliestBeginDate: Date?) {
        UserDefaults.standard.set(earliestBeginDate, forKey: Constants.nextEarliestBeginDateKey)
    }

    static var nextEarliestBeginDate: Date? {
        UserDefaults.standard.object(forKey: Constants.nextEarliestBeginDateKey) as? Date
    }
}

private extension BGTaskDiagnostics {
    enum Constants {
        static let historyKey = "debug.bgTaskRunHistory"
        static let nextEarliestBeginDateKey = "debug.bgTaskNextEarliestBeginDate"
        static let maxHistoryEntries = 30
    }
}
#endif
