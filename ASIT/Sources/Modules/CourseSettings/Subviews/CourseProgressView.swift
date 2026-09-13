//
//  CourseProgressView.swift
//  ASIT
//
//  Created by Egor Malyshev on 13.09.2026.
//

import SwiftUI

/// Полоса прогресса курса: синим — прошедшее время, оранжевым — прошедшие дни паузы,
/// красным — пропущенные дни. По тапу на паузу показываются её даты
struct CourseProgressView: View {
    let progress: CourseProgress

    @State private var selectedPause: CourseProgress.Pause?

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            bar

            HStack {
                Text(progress.startDate.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text(progress.endDate.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(summary)
                .font(.subheadline)

            if progress.pausedDaysCount > 0 || progress.missedDaysCount > 0 {
                legend
            }
        }
        .padding(.vertical, Constants.verticalPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Прогресс курса")
        .accessibilityValue(accessibilityValue)
    }

    private var bar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemFill))

                Rectangle()
                    .fill(.blue)
                    .frame(width: width * fraction(progress.elapsedDays))

                ForEach(progress.missedDays, id: \.lowerBound) { days in
                    segment(days, color: .red, width: width)
                }

                ForEach(progress.pauses) { pause in
                    segment(pause.days, color: .orange, width: width)
                }
            }
            .clipShape(Capsule())
            .frame(height: Constants.barHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                selectedPause = pause(at: location.x, width: width)
            }
            .popover(
                item: $selectedPause,
                attachmentAnchor: .rect(.rect(popoverAnchor(width: width, height: proxy.size.height))),
                arrowEdge: .bottom
            ) { pause in
                pausePopover(pause)
                    .presentationCompactAdaptation(.popover)
            }
        }
        // Зона тапа выше самой полосы — чтобы было легче попасть пальцем, но в раскладке
        // полоса занимает только свою высоту
        .frame(height: Constants.barTapHeight)
        .padding(.vertical, -(Constants.barTapHeight - Constants.barHeight) / 2)
    }

    private func segment(_ days: Range<Int>, color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width * (fraction(days.upperBound) - fraction(days.lowerBound)))
            .offset(x: width * fraction(days.lowerBound))
    }

    private var legend: some View {
        HStack(spacing: Constants.legendSpacing) {
            if progress.pausedDaysCount > 0 {
                legendItem(color: .orange, text: "На паузе \(daysText(progress.pausedDaysCount))")
            }
            if progress.missedDaysCount > 0 {
                legendItem(color: .red, text: "Пропущено \(daysText(progress.missedDaysCount))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: Constants.legendDotSpacing) {
            Circle()
                .fill(color)
                .frame(width: Constants.legendDotSize, height: Constants.legendDotSize)
            Text(text)
        }
    }

    private func pausePopover(_ pause: CourseProgress.Pause) -> some View {
        VStack(alignment: .leading, spacing: Constants.popoverSpacing) {
            Text("Пауза")
                .font(.headline)
            Text(pauseDatesText(pause))
            Text(daysText(pause.days.count))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding()
    }

    // MARK: - Helpers

    private func fraction(_ day: Int) -> CGFloat {
        CGFloat(day) / CGFloat(progress.totalDays)
    }

    /// Пауза под точкой тапа; тонкие паузы ловятся с запасом по ширине, из нескольких — ближайшая
    private func pause(at x: CGFloat, width: CGFloat) -> CourseProgress.Pause? {
        progress.pauses
            .map { pause -> (pause: CourseProgress.Pause, distance: CGFloat) in
                let minX = width * fraction(pause.days.lowerBound)
                let maxX = width * fraction(pause.days.upperBound)
                let distance = max(minX - x, x - maxX, 0)
                return (pause, distance)
            }
            .filter { $0.distance <= Constants.tapTolerance }
            .min { $0.distance < $1.distance }?
            .pause
    }

    private func popoverAnchor(width: CGFloat, height: CGFloat) -> CGRect {
        guard let selectedPause else {
            return .zero
        }
        let minX = width * fraction(selectedPause.days.lowerBound)
        let maxX = width * fraction(selectedPause.days.upperBound)
        return CGRect(x: minX, y: (height - Constants.barHeight) / 2, width: max(maxX - minX, 1), height: Constants.barHeight)
    }

    private var summary: String {
        switch progress.stage {
        case .notStarted(let daysUntilStart):
            "Курс начнётся через \(daysText(daysUntilStart))"
        case .inProgress where progress.remainingDays == 0:
            "День \(progress.elapsedDays) из \(progress.totalDays) · последний день"
        case .inProgress:
            "День \(progress.elapsedDays) из \(progress.totalDays) · осталось \(daysText(progress.remainingDays))"
        case .finished:
            "Курс завершён · \(daysText(progress.totalDays))"
        }
    }

    private func pauseDatesText(_ pause: CourseProgress.Pause) -> String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
        guard let lastDate = pause.lastDate else {
            return "С \(pause.startDate.formatted(format)) по сегодня"
        }
        guard lastDate > pause.startDate else {
            return pause.startDate.formatted(format)
        }
        return "\(pause.startDate.formatted(format)) – \(lastDate.formatted(format))"
    }

    private func daysText(_ count: Int) -> String {
        String(format: NSLocalizedString("days.count", comment: ""), count)
    }

    private var accessibilityValue: String {
        var parts = [summary]
        if progress.pausedDaysCount > 0 {
            parts.append("на паузе \(daysText(progress.pausedDaysCount))")
        }
        if progress.missedDaysCount > 0 {
            parts.append("пропущено \(daysText(progress.missedDaysCount))")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Constants

private extension CourseProgressView {
    enum Constants {
        static let barHeight: CGFloat = 12
        static let barTapHeight: CGFloat = 32
        static let tapTolerance: CGFloat = 12
        static let spacing: CGFloat = 8
        static let verticalPadding: CGFloat = 4
        static let legendSpacing: CGFloat = 16
        static let legendDotSpacing: CGFloat = 4
        static let legendDotSize: CGFloat = 8
        static let popoverSpacing: CGFloat = 4
    }
}

#Preview {
    let calendar = Calendar.current
    let course = Course.mock
    course.pauses = [
        CoursePause(
            startDate: calendar.date(byAdding: .day, value: -4, to: Date())!,
            endDate: calendar.date(byAdding: .day, value: -2, to: Date())!
        )
    ]
    return List {
        Section {
            CourseProgressView(progress: CourseProgress(course: course))
        }
    }
}
