//
//  ServiceProvider.swift
//  ASIT
//
//  Created by Egor Malyshev on 10.09.2026.
//

import Foundation

/// Единая точка сборки сервисов приложения (composition root).
final class ServiceProvider {
    let notificationService: NotificationServiceProtocol
    let courseService: CourseManagementService
    let medicationService: MedicationServiceProtocol
    let localizationService: LocalizationService

    init(
        notificationService: NotificationServiceProtocol = NotificationService(),
        medicationService: MedicationServiceProtocol = MedicationService(),
        localizationService: LocalizationService = LocalizationService()
    ) {
        self.notificationService = notificationService
        self.courseService = CourseManagementService(notificationService: notificationService)
        self.medicationService = medicationService
        self.localizationService = localizationService
    }
}
