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
    let onSelect: (Course) -> Void
    let onAddIntake: (Course) -> Void
    let onConfirmIntake: (Course) -> Void
    
    private var isIntakeDone: Bool {
        course.hasIntake(on: selectedDate)
    }
    
    /// Есть ли хотя бы один приём в истории курса
    private var hasAnyIntake: Bool {
        course.lastIntake != nil
    }
    
    /// Упаковка из последнего приёма
    private var packageName: String? {
        guard let lastIntake = course.lastIntake,
              let medication = medication else { return nil }
        return medication.packages.first { $0.id == lastIntake.packageId }?.name.ru
    }
    
    /// Дозировка из последнего приёма
    private var dosage: Dosage? {
        course.lastIntake?.dosage
    }

    var body: some View {
        HStack(spacing: 12) {
            // Индикатор статуса
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
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
                
                actionButton
                    .padding(.top, 8)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.systemGray3))
                .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isIntakeDone ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(course)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if isIntakeDone {
            // Приём на сегодня уже подтверждён
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Приём подтверждён")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if hasAnyIntake {
            // Есть предыдущие приёмы - можно подтвердить с теми же параметрами
            Button {
                onConfirmIntake(course)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Подтвердить приём")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        } else {
            // Нет приёмов - нужно сначала добавить
            Button {
                onAddIntake(course)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Добавить приём")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
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

#Preview("Нет приёмов") {
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
        onSelect: { _ in },
        onAddIntake: { _ in },
        onConfirmIntake: { _ in }
    )
    .padding()
}
