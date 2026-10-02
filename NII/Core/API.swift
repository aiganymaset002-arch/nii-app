//
//  API.swift
//  NII App
//
//  Every request the app makes. Access rules live in the database (RLS),
//  so a request the user is not allowed to make simply fails.
//

import Foundation

@MainActor
struct API {
    var db: SupabaseClient = .shared

    private var uid: UUID {
        get throws {
            guard let id = db.userID else { throw NIIError.noSession }
            return id
        }
    }

    // MARK: Profile & roles

    func myProfile() async throws -> Profile? {
        let id = try uid
        let rows: [Profile] = try await db.select("nii_profiles", "select=*&user_id=eq.\(id.uuidString)")
        return rows.first
    }

    func createProfile(fullName: String, phone: String, organization: String) async throws {
        struct New: Encodable { var userId: UUID; var fullName: String; var phone: String; var organization: String }
        try await db.insert("nii_profiles", New(userId: try uid, fullName: fullName, phone: phone, organization: organization))
    }

    func updateProfile(fullName: String, phone: String, organization: String) async throws {
        try await db.update("nii_profiles", "user_id=eq.\(try uid.uuidString)",
                            ["full_name": fullName, "phone": phone, "organization": organization])
    }

    func claimRole(code: String) async throws -> Role {
        let value: String = try await db.rpc("nii_claim_role", ["code": code])
        return Role(rawValue: value) ?? .user
    }

    func activateFamily(code: String) async throws {
        let _: Bool = try await db.rpc("nii_activate_family", ["code": code])
    }

    /// Deletes all NII data and the login (the login stays if it is also used in KKSU Online)
    func deleteAccount() async throws {
        let _: Bool = try await db.rpc("nii_delete_account")
        await db.signOut()
    }

    func people() async throws -> [Profile] {
        try await db.select("nii_profiles", "select=*&order=role,full_name")
    }

    func setRole(_ role: Role, for user: UUID) async throws {
        try await db.update("nii_profiles", "user_id=eq.\(user.uuidString)", ["role": role.rawValue])
    }

    func setFamily(_ on: Bool, for user: UUID) async throws {
        try await db.update("nii_profiles", "user_id=eq.\(user.uuidString)", ["is_family": on])
    }

    // MARK: Tasks & roadmap

    func tasks(openOnly: Bool = false) async throws -> [TaskItem] {
        try await db.select("nii_tasks", "select=*" + (openOnly ? "&status=eq.todo" : "") + "&order=status,due_date.asc.nullslast,id")
    }

    func addTask(title: String, description: String = "", due: String?, priority: String = "normal",
                 assignee: UUID?, week: Int? = nil) async throws {
        struct New: Encodable {
            var title: String; var description: String; var dueDate: String?; var priority: String
            var assignee: UUID?; var week: Int?
        }
        try await db.insert("nii_tasks", New(title: title, description: description, dueDate: due,
                                             priority: priority, assignee: assignee, week: week))
    }

    func setTask(_ task: TaskItem, done: Bool) async throws {
        try await db.update("nii_tasks", "id=eq.\(task.id)",
                            ["status": done ? "done" : "todo",
                             "done_at": done ? NIIDate.iso8601(Date()) as Any : NSNull()])
    }

    func moveTask(_ task: TaskItem, to day: String) async throws {
        try await db.update("nii_tasks", "id=eq.\(task.id)", ["due_date": day])
    }

    func assignTask(_ task: TaskItem, to user: UUID?) async throws {
        try await db.update("nii_tasks", "id=eq.\(task.id)", ["assignee": user?.uuidString as Any? ?? NSNull()])
    }

    func deleteTask(_ task: TaskItem) async throws {
        try await db.delete("nii_tasks", "id=eq.\(task.id)")
    }

    func loadRoadmap(start: Date) async throws {
        struct New: Encodable { var title: String; var dueDate: String; var week: Int }
        let rows = Roadmap.columns.flatMap { column in
            column.tasks.map { New(title: $0, dueDate: Roadmap.dueDate(week: column.week, start: start), week: column.week) }
        }
        try await db.insert("nii_tasks", rows)
    }

    func kpis() async throws -> [KPI] {
        try await db.select("nii_kpis", "select=*&order=id")
    }

    func setKPI(_ kpi: KPI, current: Int) async throws {
        try await db.update("nii_kpis", "id=eq.\(kpi.id)", ["current": max(0, current)])
    }

    // MARK: Events

    func events(includePast: Bool = false) async throws -> [NIIEvent] {
        let since = NIIDate.iso8601(Date().addingTimeInterval(-3 * 3600)).urlEncoded
        return try await db.select("nii_events", "select=*" + (includePast ? "" : "&starts_at=gte.\(since)") + "&order=starts_at")
    }

    func eventCounts() async throws -> [Int: Int] {
        let rows: [EventCount] = try await db.rpc("nii_event_counts")
        return Dictionary(rows.map { ($0.eventId, $0.taken) }, uniquingKeysWith: { a, _ in a })
    }

    func myRegistrations() async throws -> Set<Int> {
        let rows: [EventReg] = try await db.select("nii_event_regs", "select=event_id,user_id&user_id=eq.\(try uid.uuidString)")
        return Set(rows.map(\.eventId))
    }

    /// Empty unless the user is registered (or staff) — enforced by the database
    func zoomLink(event: Int) async throws -> String? {
        let rows: [EventLink] = try await db.select("nii_event_links", "select=*&event_id=eq.\(event)")
        return rows.first.map(\.zoomUrl).flatMap { $0.isEmpty ? nil : $0 }
    }

    func register(event: Int) async throws {
        struct New: Encodable { var eventId: Int }
        try await db.insert("nii_event_regs", New(eventId: event))
    }

    func cancel(event: Int) async throws {
        try await db.delete("nii_event_regs", "event_id=eq.\(event)&user_id=eq.\(try uid.uuidString)")
    }

    func attendees(event: Int) async throws -> [Profile] {
        let regs: [EventReg] = try await db.select("nii_event_regs", "select=event_id,user_id&event_id=eq.\(event)")
        guard !regs.isEmpty else { return [] }
        let ids = regs.map(\.userId.uuidString).joined(separator: ",")
        return try await db.select("nii_profiles", "select=*&user_id=in.(\(ids))&order=full_name")
    }

    struct EventDraft: Encodable {
        var type: EventKind = .conference
        var title = ""
        var description = ""
        var startsAt = Date().addingTimeInterval(7 * 86400)
        var durationMin = 90
        var location = "Онлайн (Zoom)"
        var capacity = 0
        var proOnly = false
        var published = true
        var host: UUID?
    }

    func saveEvent(_ draft: EventDraft, id: Int?, zoom: String) async throws {
        var eventID = id
        if let id {
            let data = try JSONEncoder.nii.encode(draft)
            var fields = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if draft.host == nil { fields["host"] = NSNull() }
            try await db.update("nii_events", "id=eq.\(id)", fields)
        } else {
            let created: NIIEvent = try await db.insertReturning("nii_events", draft)
            eventID = created.id
        }
        if let eventID {
            try await db.delete("nii_event_links", "event_id=eq.\(eventID)")
            try await db.insert("nii_event_links", EventLink(eventId: eventID, zoomUrl: zoom))
        }
    }

    func deleteEvent(_ id: Int) async throws {
        try await db.delete("nii_events", "id=eq.\(id)")
    }

    // MARK: Courses

    func courses() async throws -> [Course] {
        try await db.select("nii_courses", "select=*&order=created_at.desc")
    }

    func lessons(course: Int) async throws -> [Lesson] {
        try await db.select("nii_lessons", "select=*&course_id=eq.\(course)&order=sort,id")
    }

    func myEnrollments() async throws -> Set<Int> {
        let rows: [Enrollment] = try await db.select("nii_enrollments", "select=user_id,course_id&user_id=eq.\(try uid.uuidString)")
        return Set(rows.map(\.courseId))
    }

    func enroll(course: Int) async throws {
        struct New: Encodable { var courseId: Int }
        try await db.insert("nii_enrollments", New(courseId: course))
    }

    func myProgress() async throws -> [LessonProgress] {
        try await db.select("nii_progress", "select=*&user_id=eq.\(try uid.uuidString)")
    }

    func complete(lesson: Int) async throws {
        struct New: Encodable { var lessonId: Int }
        try await db.insert("nii_progress", New(lessonId: lesson))
    }

    struct CourseDraft: Encodable {
        var title = ""
        var description = ""
        var imageUrl = ""
        var isPro = false
        var published = true
    }

    @discardableResult
    func saveCourse(_ draft: CourseDraft, id: Int?) async throws -> Int {
        if let id {
            try await db.update("nii_courses", "id=eq.\(id)",
                                ["title": draft.title, "description": draft.description, "image_url": draft.imageUrl,
                                 "is_pro": draft.isPro, "published": draft.published])
            return id
        }
        let created: Course = try await db.insertReturning("nii_courses", draft)
        return created.id
    }

    func deleteCourse(_ id: Int) async throws { try await db.delete("nii_courses", "id=eq.\(id)") }

    struct LessonDraft: Encodable {
        var courseId: Int
        var title = ""
        var content = ""
        var videoUrl = ""
        var sort = 0
    }

    func saveLesson(_ draft: LessonDraft, id: Int?) async throws {
        if let id {
            try await db.update("nii_lessons", "id=eq.\(id)",
                                ["title": draft.title, "content": draft.content, "video_url": draft.videoUrl, "sort": draft.sort])
        } else {
            try await db.insert("nii_lessons", draft)
        }
    }

    func deleteLesson(_ id: Int) async throws { try await db.delete("nii_lessons", "id=eq.\(id)") }

    // MARK: Programs & applications

    func programs() async throws -> [Program] {
        try await db.select("nii_programs", "select=*&order=deadline.asc.nullslast")
    }

    func myApplications() async throws -> [Application] {
        try await db.select("nii_applications", "select=*&user_id=eq.\(try uid.uuidString)&order=created_at.desc")
    }

    func apply(program: Int, motivation: String, link: String) async throws {
        struct New: Encodable { var programId: Int; var motivation: String; var link: String }
        try await db.insert("nii_applications", New(programId: program, motivation: motivation, link: link))
    }

    func applications(program: Int) async throws -> [Application] {
        try await db.select("nii_applications", "select=*&program_id=eq.\(program)&order=created_at")
    }

    func decide(_ application: Application, status: String, note: String) async throws {
        try await db.update("nii_applications", "id=eq.\(application.id)", ["status": status, "admin_note": note])
    }

    struct ProgramDraft: Encodable {
        var kind = "Стажировка"
        var title = ""
        var description = ""
        var deadline: String?
        var published = true
    }

    func saveProgram(_ draft: ProgramDraft, id: Int?) async throws {
        if let id {
            try await db.update("nii_programs", "id=eq.\(id)",
                                ["kind": draft.kind, "title": draft.title, "description": draft.description,
                                 "deadline": draft.deadline as Any? ?? NSNull(), "published": draft.published])
        } else {
            try await db.insert("nii_programs", draft)
        }
    }

    func deleteProgram(_ id: Int) async throws { try await db.delete("nii_programs", "id=eq.\(id)") }

    // MARK: News

    func news() async throws -> [NewsItem] {
        try await db.select("nii_news", "select=*&order=created_at.desc&limit=50")
    }

    struct NewsDraft: Encodable {
        var title = ""
        var body = ""
        var imageUrl = ""
        var published = true
    }

    func saveNews(_ draft: NewsDraft, id: Int?) async throws {
        if let id {
            try await db.update("nii_news", "id=eq.\(id)",
                                ["title": draft.title, "body": draft.body, "image_url": draft.imageUrl, "published": draft.published])
        } else {
            try await db.insert("nii_news", draft)
        }
    }

    func deleteNews(_ id: Int) async throws { try await db.delete("nii_news", "id=eq.\(id)") }

    // MARK: Merch

    func products() async throws -> [MerchItem] {
        try await db.select("nii_products", "select=*&order=id")
    }

    struct ProductDraft: Encodable {
        var title = ""
        var description = ""
        var imageUrl = ""
        var price: Double = 0
        var active = true
    }

    func saveProduct(_ draft: ProductDraft, id: Int?) async throws {
        if let id {
            try await db.update("nii_products", "id=eq.\(id)",
                                ["title": draft.title, "description": draft.description, "image_url": draft.imageUrl,
                                 "price": draft.price, "active": draft.active])
        } else {
            try await db.insert("nii_products", draft)
        }
    }

    func deleteProduct(_ id: Int) async throws { try await db.delete("nii_products", "id=eq.\(id)") }

    /// Price and title are taken from the product by the database
    func order(product: Int, note: String) async throws -> Order {
        struct New: Encodable { var productId: Int; var note: String }
        return try await db.insertReturning("nii_orders", New(productId: product, note: note))
    }

    func myOrders() async throws -> [Order] {
        try await db.select("nii_orders", "select=*&user_id=eq.\(try uid.uuidString)&order=created_at.desc")
    }

    func allOrders() async throws -> [Order] {
        try await db.select("nii_orders", "select=*&order=created_at.desc&limit=200")
    }

    func setOrder(_ order: Order, status: String) async throws {
        try await db.update("nii_orders", "id=eq.\(order.id)", ["status": status])
    }
}
