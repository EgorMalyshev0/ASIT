//
//  CourseManagementServiceProtocol.swift
//  ASIT
//
//  Created by Egor Malyshev on 28.12.2025.
//

import Combine
import Foundation

protocol CourseManagementServiceProtocol: AnyObject {
    var coursesPublisher: AnyPublisher<[Course], Never> { get }
    var courses: [Course] { get }

    // MARK: - Course CRUD
    func addCourse(_ course: Course)
    func updateCourse(_ course: Course)
    func deleteCourse(_ course: Course)
    func fetchCourses()

    // MARK: - Intake CRUD
    func addIntake(_ intake: Intake, to course: Course)
    func updateIntake(_ intake: Intake)
    func deleteIntake(_ intake: Intake, from course: Course)
    
    // MARK: - Reminder CRUD
    func addReminder(_ reminder: Reminder, to course: Course)
    func updateReminder(_ reminder: Reminder, hour: Int, minute: Int, in course: Course)
    func deleteReminder(_ reminder: Reminder, from course: Course)
    func handleTakenActionFromPush(courseId: UUID, date: Date)
    
    // MARK: - Import/Export
    func importCourse(from dto: CourseExportDTO)
}
