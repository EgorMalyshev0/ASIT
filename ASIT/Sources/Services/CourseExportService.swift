//
//  CourseExportService.swift
//  ASIT
//
//  Created by Egor Malyshev on 22.01.2026.
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// Transferable wrapper для экспорта курса через ShareLink
struct CourseFileExport: Transferable {
    let course: Course
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            let data = try await CourseExportService.export(export.course)
            let fileName = await CourseExportService.generateFileName(for: export.course)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            return SentTransferredFile(tempURL)
        }
    }
}

enum CourseExportError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case unsupportedVersion(Int)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Не удалось экспортировать курс"
        case .decodingFailed:
            return "Не удалось прочитать файл курса"
        case .unsupportedVersion(let version):
            return "Неподдерживаемая версия файла: \(version)"
        }
    }
}

struct CourseExportService {
    static let fileExtension = "json"
    
    /// Экспортирует курс в JSON Data
    static func export(_ course: Course) throws -> Data {
        let dto = CourseExportDTO(course: course)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(dto) else {
            throw CourseExportError.encodingFailed
        }
        return data
    }
    
    /// Импортирует курс из JSON Data
    static func importCourse(from data: Data) throws -> CourseExportDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let dto = try? decoder.decode(CourseExportDTO.self, from: data) else {
            throw CourseExportError.decodingFailed
        }
        
        guard dto.version <= CourseExportDTO.currentVersion else {
            throw CourseExportError.unsupportedVersion(dto.version)
        }
        
        return dto
    }
    
    /// Генерирует имя файла для экспорта
    static func generateFileName(for course: Course) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "\(course.medicationId)_\(dateString).\(fileExtension)"
    }
}

