//
//  IntakeCardView.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import SwiftUI

/// Карточка приёма для конкретного курса на выбранную дату
struct IntakeCardView: View {
    let course: Course
    let selectedDate: Date
    let medication: Medication?
    let onTap: () -> Void
    let onConfirmIntake: () -> Void
    
    private var intakeForDate: Intake? {
        course.intake(on: selectedDate)
    }
    
    private var isIntakeDone: Bool {
        intakeForDate != nil
    }
    
    /// Есть ли хотя бы один приём в истории курса (для быстрого подтверждения)
    private var hasAnyIntake: Bool {
        course.lastIntake != nil
    }
    
    /// Упаковка из приёма на эту дату или из последнего приёма
    private var packageName: String? {
        let targetIntake = intakeForDate ?? course.lastIntake
        guard let targetIntake = targetIntake,
              let medication = medication else { return nil }
        return medication.packages.first { $0.id == targetIntake.packageId }?.name.ru
    }
    
    /// Дозировка из приёма на эту дату или из последнего приёма
    private var dosage: Dosage? {
        (intakeForDate ?? course.lastIntake)?.dosage
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(medication?.name.ru ?? "Препарат")
                    .font(.headline)
                    .foregroundStyle(isIntakeDone ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let packageName = packageName {
                    Text(packageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let dosage = dosage {
                    Text("Доза: \(dosage.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                statusView
                    .padding(.top, 4)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.systemGray3))
                .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isIntakeDone ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        if isIntakeDone {
            // Приём подтверждён
            Text("Приём подтверждён")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if hasAnyIntake {
            // Есть предыдущие приёмы - можно быстро подтвердить
            Button {
                onConfirmIntake()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Подтвердить приём")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        } else {
            // Нет приёмов - только статус
            HStack {
                Text("Нажмите для добавления")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var statusColor: Color {
        if isIntakeDone {
            return .green
        } else if hasAnyIntake {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var borderColor: Color {
        if isIntakeDone {
            return .green.opacity(0.3)
        } else if hasAnyIntake {
            return .orange.opacity(0.3)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    IntakeCardView(
        course: .mock,
        selectedDate: .now,
        medication: Medication(
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
        ),
        onTap: {},
        onConfirmIntake: {}
    )
    .padding()
}
