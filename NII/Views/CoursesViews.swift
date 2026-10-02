//
//  CoursesViews.swift
//  NII App
//
//  Courses: catalog, enrollment, lessons with video, progress and a certificate.
//  The organizer creates courses and lessons right here.
//

import SwiftUI
import WebKit

struct CoursesView: View {
    @EnvironmentObject private var state: AppState

    @State private var courses: [Course] = []
    @State private var enrolled: Set<Int> = []
    @State private var editing = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                let mine = courses.filter { enrolled.contains($0.id) }
                if !mine.isEmpty {
                    SectionTitle(title: "Мои курсы")
                    ForEach(mine) { course in
                        NavigationLink { CourseDetailView(course: course) } label: { CourseRow(course: course) }
                            .buttonStyle(.plain)
                    }
                }
                SectionTitle(title: "Все курсы")
                if courses.isEmpty { EmptyCard(text: "Курсы скоро появятся") }
                ForEach(courses.filter { !enrolled.contains($0.id) }) { course in
                    NavigationLink { CourseDetailView(course: course) } label: { CourseRow(course: course) }
                        .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Курсы")
        .toolbar {
            if state.role == .admin {
                Button { editing = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { CourseEditor(course: nil) }
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        await attempt($error) {
            async let c = state.api.courses()
            async let e = state.api.myEnrollments()
            courses = try await c
            enrolled = (try? await e) ?? []
        }
    }
}

struct CourseRow: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: course.imageUrl, height: 120, icon: "graduationcap.fill")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(course.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    Spacer()
                    if course.isPro { ProBadge() } else { Chip(text: "бесплатно", color: .green) }
                }
                if !course.description.isEmpty {
                    Text(course.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if !course.published { Chip(text: "черновик", color: .gray) }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var pro: ProStore // refreshes Pro gating after a purchase
    @Environment(\.dismiss) private var dismiss

    @State var course: Course
    @State private var lessons: [Lesson] = []
    @State private var enrolled = false
    @State private var done: Set<Int> = []
    @State private var editingCourse = false
    @State private var editingLesson: Lesson?
    @State private var addingLesson = false
    @State private var showPro = false
    @State private var error: String?

    private var isAdmin: Bool { state.role == .admin }
    private var locked: Bool { course.isPro && !state.hasPro }
    private var progress: Double { lessons.isEmpty ? 0 : Double(lessons.filter { done.contains($0.id) }.count) / Double(lessons.count) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImage(url: course.imageUrl, height: 180, icon: "graduationcap.fill")
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                HStack {
                    Text(course.title).font(.title2.bold())
                    Spacer()
                    if course.isPro { ProBadge() }
                }
                if !course.description.isEmpty { Text(course.description).foregroundStyle(.secondary) }

                if enrolled && !lessons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Прогресс: \(Int(progress * 100))%").font(.subheadline.weight(.semibold))
                        ProgressView(value: progress)
                    }
                    .card()
                    if progress >= 1 {
                        CertificateCard(name: state.profile?.fullName ?? "", course: course.title)
                    }
                }

                if locked {
                    Button { showPro = true } label: { Label("Открыть курс с NII Pro", systemImage: "lock.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: .orange))
                } else if !enrolled {
                    Button("Присоединиться к курсу") {
                        Task { await attempt($error) { try await state.api.enroll(course: course.id); await load() } }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                SectionTitle(title: "Уроки (\(lessons.count))", action: isAdmin ? ("Добавить", { addingLesson = true } as () -> Void) : nil)
                if lessons.isEmpty { EmptyCard(text: "Уроков пока нет") }
                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                    lessonRow(index: index, lesson: lesson)
                }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Курс")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAdmin {
                Menu {
                    Button("Изменить курс", systemImage: "pencil") { editingCourse = true }
                    Button("Добавить урок", systemImage: "plus") { addingLesson = true }
                    Button("Удалить курс", systemImage: "trash", role: .destructive) {
                        Task { await attempt($error) { try await state.api.deleteCourse(course.id); dismiss() } }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editingCourse, onDismiss: { Task { await reloadCourse() } }) { CourseEditor(course: course) }
        .sheet(isPresented: $addingLesson, onDismiss: { Task { await load() } }) {
            LessonEditor(courseId: course.id, lesson: nil, nextSort: (lessons.map(\.sort).max() ?? 0) + 1)
        }
        .sheet(item: $editingLesson, onDismiss: { Task { await load() } }) { lesson in
            LessonEditor(courseId: course.id, lesson: lesson, nextSort: lesson.sort)
        }
        .sheet(isPresented: $showPro) { NavigationStack { ProView() } }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($error)
    }

    @ViewBuilder private func lessonRow(index: Int, lesson: Lesson) -> some View {
        let open = isAdmin || (enrolled && !locked)
        let label = HStack {
            Image(systemName: done.contains(lesson.id) ? "checkmark.circle.fill" : (open ? "play.circle" : "lock"))
                .foregroundStyle(done.contains(lesson.id) ? .green : .niiNavy)
                .font(.title3)
            Text("\(index + 1). \(lesson.title)").foregroundStyle(.primary).multilineTextAlignment(.leading)
            Spacer()
            if open { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        }
        .card()

        if open {
            NavigationLink {
                LessonView(lesson: lesson, isDone: done.contains(lesson.id)) { await load() }
            } label: { label }
                .buttonStyle(.plain)
                .contextMenu {
                    if isAdmin {
                        Button("Изменить", systemImage: "pencil") { editingLesson = lesson }
                        Button("Удалить", systemImage: "trash", role: .destructive) {
                            Task { await attempt($error) { try await state.api.deleteLesson(lesson.id); await load() } }
                        }
                    }
                }
        } else {
            label
        }
    }

    private func reloadCourse() async {
        if let fresh = try? await state.api.courses().first(where: { $0.id == course.id }) { course = fresh }
        await load()
    }

    private func load() async {
        await attempt($error) {
            async let l = state.api.lessons(course: course.id)
            async let e = state.api.myEnrollments()
            async let p = state.api.myProgress()
            lessons = try await l
            enrolled = (try? await e)?.contains(course.id) ?? false
            done = Set(((try? await p) ?? []).map(\.lessonId))
        }
    }
}

struct LessonView: View {
    @EnvironmentObject private var state: AppState

    let lesson: Lesson
    @State var isDone: Bool
    var onChange: () async -> Void
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = embedVideoURL(lesson.videoUrl), !lesson.videoUrl.isEmpty {
                    VideoPlayerView(url: url)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Text(lesson.title).font(.title2.bold())
                if !lesson.content.isEmpty {
                    Text(.init(lesson.content)).textSelection(.enabled)
                }
                if isDone {
                    Label("Урок пройден", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.headline)
                } else {
                    Button("Отметить как пройденный") {
                        Task {
                            await attempt($error) {
                                try await state.api.complete(lesson: lesson.id)
                                isDone = true
                                await onChange()
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .green))
                }
            }
            .padding()
        }
        .navigationTitle("Урок")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($error)
    }
}

/// YouTube or any web video inside the app
struct VideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.scrollView.isScrollEnabled = false
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}
}

// MARK: - Certificate

struct CertificateView: View {
    let name: String
    let course: String
    var date = Date()

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "atom").font(.system(size: 44)).foregroundStyle(Color.niiNavy)
            Text("НИИ ИНКЛЮЗИВНОГО ИНЖИНИРИНГА").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            Text("СЕРТИФИКАТ").font(.system(size: 34, weight: .heavy, design: .serif)).foregroundStyle(Color.niiNavy)
            Text("подтверждает, что").font(.subheadline).foregroundStyle(.secondary)
            Text(name).font(.system(size: 26, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
            Text("успешно завершил(а) курс").font(.subheadline).foregroundStyle(.secondary)
            Text("«\(course)»").font(.title3.bold()).multilineTextAlignment(.center)
            Text(NIIDate.short(date)).font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
        }
        .padding(32)
        .frame(width: 600, height: 420)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(LinearGradient.nii, lineWidth: 10))
        .environment(\.colorScheme, .light)
    }
}

struct CertificateCard: View {
    let name: String
    let course: String
    @State private var image: Image?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Курс завершён! Ваш сертификат готов", systemImage: "rosette").font(.headline)
            if let image {
                image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
                ShareLink(item: image, preview: SharePreview("Сертификат НИИ", image: image)) {
                    Label("Сохранить или отправить", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle(color: .niiIndigo))
            }
        }
        .card()
        .task { render() }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: CertificateView(name: name, course: course))
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}

// MARK: - Editors (organizer)

struct CourseEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let course: Course?
    @State private var draft = API.CourseDraft()
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название курса", text: $draft.title)
                    TextField("Описание: чему научится участник", text: $draft.description, axis: .vertical).lineLimit(4...10)
                    TextField("Ссылка на обложку (необязательно)", text: $draft.imageUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Toggle("Только для NII Pro", isOn: $draft.isPro)
                    Toggle("Опубликован", isOn: $draft.published)
                } footer: {
                    Text("Уроки добавляются на странице курса после сохранения.")
                }
            }
            .navigationTitle(course == nil ? "Новый курс" : "Изменить курс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saving = true
                        Task {
                            await attempt($error) { try await state.api.saveCourse(draft, id: course?.id); dismiss() }
                            saving = false
                        }
                    }
                    .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .errorAlert($error)
            .onAppear {
                if let course {
                    draft = API.CourseDraft(title: course.title, description: course.description, imageUrl: course.imageUrl,
                                            isPro: course.isPro, published: course.published)
                }
            }
        }
    }
}

struct LessonEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let courseId: Int
    let lesson: Lesson?
    let nextSort: Int
    @State private var draft: API.LessonDraft
    @State private var saving = false
    @State private var error: String?

    init(courseId: Int, lesson: Lesson?, nextSort: Int) {
        self.courseId = courseId
        self.lesson = lesson
        self.nextSort = nextSort
        var d = API.LessonDraft(courseId: courseId)
        if let lesson {
            d.title = lesson.title; d.content = lesson.content; d.videoUrl = lesson.videoUrl; d.sort = lesson.sort
        } else {
            d.sort = nextSort
        }
        _draft = State(initialValue: d)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название урока", text: $draft.title)
                    TextField("Ссылка на видео (YouTube и др.)", text: $draft.videoUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Stepper("Порядок: \(draft.sort)", value: $draft.sort, in: 0...999)
                }
                Section("Текст урока") {
                    TextField("Материал, задания, ссылки", text: $draft.content, axis: .vertical).lineLimit(8...30)
                }
            }
            .navigationTitle(lesson == nil ? "Новый урок" : "Изменить урок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saving = true
                        Task {
                            await attempt($error) { try await state.api.saveLesson(draft, id: lesson?.id); dismiss() }
                            saving = false
                        }
                    }
                    .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .errorAlert($error)
        }
    }
}
