//
//  DayDetailView.swift
//  ASIT
//
//  Created by Egor Malyshev on 29.12.2025.
//

import SwiftUI

/// Детальный вью для конкретного дня - показывает все курсы и их статусы
struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    let courses: [Course]
    let medications: [Medication]
    
    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        return formatter.string(from: date).capitalized
    }
    
    private var activeCourses: [Course] {
        courses.filter { course in
            date >= course.startDate && date <= course.endDate && !course.isCompleted && !course.isPaused
        }
    }
    
    private func medication(for course: Course) -> Medication? {
        medications.first { $0.id == course.medicationId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if activeCourses.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(activeCourses) { course in
                            DayDetailCourseRow(
                                course: course,
                                date: date,
                                medication: medication(for: course)
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Нет активных курсов")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("На эту дату нет запланированных приёмов")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
}

// MARK: - DayDetailCourseRow

private struct DayDetailCourseRow: View {
    let course: Course
    let date: Date
    let medication: Medication?
    
    private var intake: Intake? {
        course.intake(on: date)
    }
    
    private var isIntakeDone: Bool {
        intake != nil
    }
    
    /// Упаковка из приёма на этот день или из последнего приёма
    private var packageName: String? {
        let targetIntake = intake ?? course.lastIntake
        guard let targetIntake = targetIntake,
              let medication = medication else { return nil }
        return medication.packages.first { $0.id == targetIntake.packageId }?.name.ru
    }
    
    /// Дозировка из приёма на этот день или из последнего приёма
    private var dosage: Dosage? {
        (intake ?? course.lastIntake)?.dosage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(isIntakeDone ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                
                Text(medication?.name.ru ?? "Препарат")
                    .font(.headline)
                
                Spacer()
                
                Text(isIntakeDone ? "Принято" : "Не принято")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isIntakeDone ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isIntakeDone ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    )
            }
            
            Divider()
            
            if let packageName = packageName {
                HStack {
                    Text("Упаковка:")
                        .foregroundStyle(.secondary)
                    Text(packageName)
                }
                .font(.subheadline)
            }
            
            if let dosage = dosage {
                HStack {
                    Text("Дозировка:")
                        .foregroundStyle(.secondary)
                    Text(dosage.displayName)
                }
                .font(.subheadline)
            }
            
            if let intake = intake, let comment = intake.comment, !comment.isEmpty {
                HStack(alignment: .top) {
                    Text("Комментарий:")
                        .foregroundStyle(.secondary)
                    Text(comment)
                }
                .font(.subheadline)
            }
            
            if let intake = intake {
                HStack {
                    Text("Время приёма:")
                        .foregroundStyle(.secondary)
                    Text(intakeTime(intake.date))
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
    
    private func intakeTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    DayDetailView(
        date: .now,
        courses: [.mock],
        medications: [
            Medication(
                id: "staloral_birch_pollen",
                name: LocalizedName(ru: "Сталораль Аллерген пыльцы берёзы"),
                therapyType: .slit,
                packages: [
                    Medication.Package(
                        id: "bottle-10-ir",
                        name: LocalizedName(ru: "Флакон с синей крышкой"),
                        dosages: [Dosage(type: .press, amount: 3)]
                    )
                ]
            )
        ]
    )
}

