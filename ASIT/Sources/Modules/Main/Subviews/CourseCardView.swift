//
//  CourseCardView.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import SwiftUI

struct CourseCardView: View {
    @EnvironmentObject var localizationService: LocalizationService
    let course: Course
    let onSelect: (Course) -> Void
    let onIntake: (Course) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Сталораль Аллерген Берёзы")
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Флакон с голубой крышкой - 10 ИР/мл")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Доза - 3 нажатия")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Подтвердить приём") {
                    onIntake(course)
                }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.systemGray))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    CourseCardView(course: .mock, onSelect: {_ in}, onIntake: {_ in})
        .padding()
}
