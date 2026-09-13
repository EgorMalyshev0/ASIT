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
    /// Курсы, которые идут в указанный день (включая стоящие на паузе)
    func activeCourses(on date: Date) -> [Course]
    /// Курсы, приём по которым ожидается в указанный день — дни паузы не учитываются
    /// ни как принятые, ни как пропущенные
    func trackableCourses(on date: Date) -> [Course]

    // MARK: - Intake CRUD
    func addIntake(_ intake: Intake, to course: Course)
    func updateIntake(_ intake: Intake)
    func deleteIntake(_ intake: Intake, from course: Course)
    
    // MARK: - Reminder CRUD
    func handleTakenActionFromPush(courseId: UUID, date: Date)
    func setReminderEnabled(_ isEnabled: Bool, course: Course)
    func updateReminderTime(_ newTime: Date, course: Course)

    // MARK: - Pause
    func pauseCourse(_ course: Course)
    func resumeCourse(_ course: Course)

    // MARK: - Import/Export
    func importCourse(from dto: CourseExportDTO)
}
