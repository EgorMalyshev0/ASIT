//
//  DebugReminderScheduleView.swift
//  ASIT
//
//  Created by Egor Malyshev on 12.09.2026.
//

#if DEBUG
import SwiftUI
import UserNotifications

/// Отладочная секция для ручного тестирования планирования уведомлений в течение нескольких дней:
/// список реально запланированных в системе pending-уведомлений для курса и история запусков
/// BGAppRefreshTask. Только для DEBUG-сборок, в Release не собирается и никак не участвует.
struct DebugReminderScheduleView: View {
    let course: Course

    @State private var pendingRequests: [UNNotificationRequest] = []
    @State private var lastRefreshed: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bgTaskSection
            Divider()
            pendingRequestsSection

            Button("Обновить") {
                Task { await loadPendingRequests() }
            }
            .font(.caption)
        }
        .task {
            await loadPendingRequests()
        }
    }

    private var bgTaskSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BGAppRefreshTask").font(.caption).bold()

            if let next = BGTaskDiagnostics.nextEarliestBeginDate {
                Text("Следующая попытка не раньше: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Запрос не запланирован")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let runs = BGTaskDiagnostics.history
            if runs.isEmpty {
                Text("Пока не запускался")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runs.prefix(10)) { run in
                    Text("\(run.firedAt.formatted(date: .abbreviated, time: .standard)) — \(run.outcome)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Запланированные уведомления курса").font(.caption).bold()

            if let lastRefreshed {
                Text("Обновлено: \(lastRefreshed.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let relevantRequests = pendingRequests
                .filter { request in course.schedules.contains { request.identifier.hasPrefix("\($0.id.uuidString)-") } }
                .sorted { (fireDate(for: $0) ?? .distantFuture) < (fireDate(for: $1) ?? .distantFuture) }

            if relevantRequests.isEmpty {
                Text("Нет запланированных уведомлений")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relevantRequests, id: \.identifier) { request in
                    let dateText = fireDate(for: request)?.formatted(date: .abbreviated, time: .shortened) ?? "?"
                    Text("\(dateText) — \(request.identifier)")
                        .font(.caption2)
                }
            }
        }
    }

    private func fireDate(for request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
    }

    private func loadPendingRequests() async {
        pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        lastRefreshed = Date()
    }
}
#endif
