//
//  Models.swift
//  NII App
//
//  Rows of the nii_* tables (backend/schema.sql). Keys are snake_case in the database.
//

import Foundation

enum Role: String, Codable, CaseIterable, Identifiable {
    case admin, team, user
    var id: String { rawValue }

    var title: String {
        switch self {
        case .admin: return "Организатор"
        case .team: return "Команда НИИ"
        case .user: return "Участник"
        }
    }

    var hint: String {
        switch self {
        case .admin: return "Управление НИИ: задачи, план 90 дней, курсы, конференции, заявки"
        case .team: return "Сотрудники и исследователи: задачи, онлайн-лаборатория, встречи"
        case .user: return "Курсы, конференции, программы, онлайн-лаборатория, новости"
        }
    }
}

struct Profile: Codable, Identifiable, Equatable {
    var userId: UUID
    var fullName: String
    var role: Role
    var phone: String
    var organization: String
    var isFamily: Bool
    var id: UUID { userId }
    var isStaff: Bool { role != .user }
}

struct TaskItem: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var description: String
    var dueDate: String?
    var week: Int?
    var priority: String
    var status: String
    var assignee: UUID?
    var createdBy: UUID?

    var isDone: Bool { status == "done" }
    var isOverdue: Bool { !isDone && (dueDate.map { $0 < NIIDate.today } ?? false) }
    var weekLabel: String? { week.map { $0 == 0 ? "Старт" : "Неделя \($0)" } }
}

struct KPI: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var current: Int
    var goal: Int
    var progress: Double { goal > 0 ? min(1, Double(current) / Double(goal)) : 0 }
}

enum EventKind: String, Codable, CaseIterable, Identifiable {
    case conference, seminar, lab, meeting
    var id: String { rawValue }

    var title: String {
        switch self {
        case .conference: return "Конференция"
        case .seminar: return "Семинар"
        case .lab: return "Онлайн-лаборатория"
        case .meeting: return "Встреча"
        }
    }

    var icon: String {
        switch self {
        case .conference: return "person.3.fill"
        case .seminar: return "graduationcap.fill"
        case .lab: return "flask.fill"
        case .meeting: return "video.fill"
        }
    }
}

struct NIIEvent: Codable, Identifiable, Equatable {
    var id: Int
    var type: EventKind
    var title: String
    var description: String
    var startsAt: Date
    var durationMin: Int
    var location: String
    var capacity: Int
    var proOnly: Bool
    var published: Bool
    var host: UUID?

    var endsAt: Date { startsAt.addingTimeInterval(TimeInterval(durationMin * 60)) }
    var isLive: Bool { Date() >= startsAt.addingTimeInterval(-15 * 60) && Date() <= endsAt }
    var isPast: Bool { endsAt < Date() }
}

struct EventLink: Codable, Equatable { var eventId: Int; var zoomUrl: String }
struct EventReg: Codable, Equatable { var eventId: Int; var userId: UUID }
struct EventCount: Codable, Equatable { var eventId: Int; var taken: Int }

struct Course: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var description: String
    var imageUrl: String
    var isPro: Bool
    var published: Bool
}

struct Lesson: Codable, Identifiable, Equatable {
    var id: Int
    var courseId: Int
    var title: String
    var content: String
    var videoUrl: String
    var sort: Int
}

struct Enrollment: Codable, Equatable { var userId: UUID; var courseId: Int }
struct LessonProgress: Codable, Equatable { var userId: UUID; var lessonId: Int; var doneAt: Date }

struct Program: Codable, Identifiable, Equatable {
    var id: Int
    var kind: String
    var title: String
    var description: String
    var deadline: String?
    var published: Bool
    var isClosed: Bool { deadline.map { $0 < NIIDate.today } ?? false }
}

struct Application: Codable, Identifiable, Equatable {
    var id: Int
    var programId: Int
    var userId: UUID
    var motivation: String
    var link: String
    var status: String
    var adminNote: String
    var createdAt: Date

    var statusTitle: String {
        switch status {
        case "accepted": return "Принята"
        case "rejected": return "Отклонена"
        default: return "На рассмотрении"
        }
    }
}

struct NewsItem: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var body: String
    var imageUrl: String
    var published: Bool
    var createdAt: Date
}

struct MerchItem: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var description: String
    var imageUrl: String
    var price: Double
    var active: Bool
}

struct Order: Codable, Identifiable, Equatable {
    var id: Int
    var userId: UUID
    var productId: Int?
    var title: String
    var amount: Double
    var note: String
    var status: String
    var createdAt: Date

    var statusTitle: String {
        switch status {
        case "paid": return "Оплачен"
        case "shipped": return "Выдан"
        case "cancelled": return "Отменён"
        default: return "Ожидает оплаты"
        }
    }
}

// MARK: - Helpers

extension Double {
    var usd: String {
        let whole = self == rounded() ? String(Int(self)) : String(format: "%.2f", self)
        return "$" + whole
    }
}

/// YouTube watch / youtu.be / shorts links → embeddable player URL
func embedVideoURL(_ text: String) -> URL? {
    let patterns = ["youtube.com/watch?v=", "youtu.be/", "youtube.com/shorts/", "youtube.com/embed/"]
    for p in patterns {
        if let range = text.range(of: p) {
            let id = text[range.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            if id.count >= 6 { return URL(string: "https://www.youtube.com/embed/\(id)?playsinline=1") }
        }
    }
    return URL(string: text).flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
}
