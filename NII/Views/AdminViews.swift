//
//  AdminViews.swift
//  NII App
//
//  Organizer: dashboard, 90-day roadmap, management menu, people.
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var state: AppState

    @State private var today: [TaskItem] = []
    @State private var allTasks: [TaskItem] = []
    @State private var kpis: [KPI] = []
    @State private var events: [NIIEvent] = []
    @State private var counts: [Int: Int] = [:]
    @State private var stats = (people: 0, newApplications: 0, newOrders: 0)
    @State private var quickTask = ""
    @State private var error: String?

    private var roadmap: (done: Int, total: Int) {
        let plan = allTasks.filter { $0.week != nil }
        return (plan.filter(\.isDone).count, plan.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NIIDate.short(Date()) + " · НИИ Инклюзивного Инжиниринга").font(.subheadline).foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    stat("\(stats.people)", "Участники", "person.2.fill")
                    stat("\(stats.newApplications)", "Новые заявки", "doc.text.fill", alert: stats.newApplications > 0)
                    stat("\(stats.newOrders)", "Заказы мерча", "tshirt.fill", alert: stats.newOrders > 0)
                }

                SectionTitle(title: "Мои задачи на сегодня")
                HStack {
                    TextField("Быстро добавить задачу…", text: $quickTask)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await addQuick() } }
                    Button { Task { await addQuick() } } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                        .disabled(quickTask.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if today.isEmpty { Text("На сегодня всё сделано 🎉").foregroundStyle(.secondary).padding(.vertical, 6) }
                    ForEach(today) { task in
                        HStack(alignment: .top) {
                            Button {
                                Task { await attempt($error) { try await state.api.setTask(task, done: true); await load() } }
                            } label: { Image(systemName: "circle").font(.title3) }
                                .buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text((task.priority == "high" ? "🔥 " : "") + task.title)
                                if let label = task.weekLabel { Chip(text: label, color: .niiIndigo) }
                            }
                            Spacer()
                            if task.isOverdue { Text(NIIDate.short(day: task.dueDate)).font(.caption).foregroundStyle(.red) }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .card()

                NavigationLink { RoadmapView() } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("План «90 дней до масштабного результата»").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        if roadmap.total > 0 {
                            Text("\(Int(Double(roadmap.done) / Double(roadmap.total) * 100))% выполнено").font(.title2.bold())
                            ProgressView(value: Double(roadmap.done), total: Double(roadmap.total)).tint(.white)
                        } else {
                            Text("Загрузить план в задачи →").font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient.nii, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                SectionTitle(title: "Ключевые результаты · 90 дней")
                VStack(spacing: 14) {
                    ForEach(kpis) { kpi in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(kpi.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Stepper("\(kpi.current) / \(kpi.goal)", value: Binding(
                                    get: { kpi.current },
                                    set: { value in Task { await attempt($error) { try await state.api.setKPI(kpi, current: value); await load() } } }
                                ), in: 0...10_000)
                                .fixedSize()
                                .font(.caption)
                            }
                            ProgressView(value: kpi.progress).tint(kpi.progress >= 1 ? .green : .niiNavy)
                        }
                    }
                }
                .card()

                SectionTitle(title: "Ближайшие мероприятия")
                if events.isEmpty { EmptyCard(text: "Ничего не запланировано.") }
                ForEach(events.prefix(5)) { event in
                    NavigationLink { EventDetailView(event: event) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(NIIDate.dateTime(event.startsAt)).font(.caption).foregroundStyle(.secondary)
                                Text(event.title).font(.headline)
                            }
                            Spacer()
                            Text("👥 \(counts[event.id] ?? 0)" + (event.capacity > 0 ? " / \(event.capacity)" : "")).font(.caption)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Добрый день, \(state.profile?.fullName.split(separator: " ").first.map(String.init) ?? "") 👋")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private func stat(_ value: String, _ label: String, _ icon: String, alert: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(Color.niiIndigo)
            Text(value).font(.title.bold()).foregroundStyle(alert ? .orange : .primary)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }

    private func addQuick() async {
        let title = quickTask.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        await attempt($error) {
            try await state.api.addTask(title: title, due: NIIDate.today, assignee: nil)
            quickTask = ""
            await load()
        }
    }

    private func load() async {
        await attempt($error) {
            let api = state.api
            let me = api.db.userID
            allTasks = try await api.tasks()
            today = allTasks.filter { !$0.isDone && ($0.assignee == nil || $0.assignee == me) && ($0.dueDate.map { $0 <= NIIDate.today } ?? true) }
            kpis = try await api.kpis()
            events = try await api.events()
            counts = try await api.eventCounts()
            let people = try await api.people()
            var newApplications = 0
            for program in try await api.programs() {
                newApplications += try await api.applications(program: program.id).filter { $0.status == "submitted" }.count
            }
            let orders = try await api.allOrders().filter { $0.status == "new" }.count
            stats = (people.filter { $0.role == .user }.count, newApplications, orders)
        }
    }
}

struct RoadmapView: View {
    @EnvironmentObject private var state: AppState
    @State private var tasks: [TaskItem] = []
    @State private var people: [Profile] = []
    @State private var start = Date()
    @State private var loaded = true
    @State private var error: String?

    private let colors: [Color] = [.niiIndigo, .blue, .cyan, .teal, .green, .mint, .orange, .red, .pink, .purple, .niiFuchsia, .indigo, .niiNavy]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Точка А → Точка Б").font(.caption).foregroundStyle(.white.opacity(0.8))
                    Text("90 дней до масштабного результата").font(.title2.bold())
                    Text("От исследования — к прототипу, от идеи — к реальному решению.").font(.subheadline)
                    if !tasks.isEmpty {
                        let done = tasks.filter(\.isDone).count
                        Text("\(done) из \(tasks.count) задач").font(.headline).padding(.top, 4)
                        ProgressView(value: Double(done), total: Double(tasks.count)).tint(.white)
                    }
                }
                .foregroundStyle(.white)
                .listRowBackground(LinearGradient.nii)
            }

            if !loaded {
                Section("Запустить план") {
                    Text("Все 39 задач с карты появятся в «Задачах» со сроками по неделям.").font(.subheadline)
                    DatePicker("День 1", selection: $start, displayedComponents: .date)
                    Button("🚀 Загрузить план в задачи") {
                        Task { await attempt($error) { try await state.api.loadRoadmap(start: start); await load() } }
                    }
                }
            }

            ForEach(Roadmap.columns, id: \.week) { column in
                Section {
                    let list = tasks.filter { $0.week == column.week }
                    if list.isEmpty {
                        ForEach(column.tasks, id: \.self) { Text("• " + $0).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    ForEach(list) { task in
                        HStack(alignment: .top) {
                            Button {
                                Task { await attempt($error) { try await state.api.setTask(task, done: !task.isDone); await load() } }
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.square.fill" : "square").foregroundStyle(task.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.subheadline).strikethrough(task.isDone)
                                Menu {
                                    Button("Не назначено") { assign(task, nil) }
                                    ForEach(people) { person in Button(person.fullName) { assign(task, person.userId) } }
                                } label: {
                                    Text("👤 " + (people.first { $0.userId == task.assignee }?.fullName ?? "Не назначено") + " · до " + NIIDate.short(day: task.dueDate))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(Roadmap.title(column.week)).bold()
                        Spacer()
                        Text(Roadmap.days(column.week))
                    }
                    .foregroundStyle(colors[column.week % colors.count])
                }
            }

            Section("Точка Б · День 90") {
                Text("НИИ — признанный международный центр Inclusive Engineering с исследованиями, партнёрами, грантами, прототипами и сильной командой.")
                    .font(.subheadline)
                ForEach(Roadmap.pointB, id: \.self) { Label($0, systemImage: "checkmark").foregroundStyle(Color.niiFuchsia) }
            }
        }
        .navigationTitle("План 90 дней")
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($error)
    }

    private func assign(_ task: TaskItem, _ user: UUID?) {
        Task { await attempt($error) { try await state.api.assignTask(task, to: user); await load() } }
    }

    private func load() async {
        await attempt($error) {
            tasks = try await state.api.tasks().filter { $0.week != nil }.sorted { ($0.week ?? 0, $0.id) < ($1.week ?? 0, $1.id) }
            loaded = !tasks.isEmpty
            if people.isEmpty { people = try await state.api.people().filter(\.isStaff) }
        }
    }
}

struct ManageView: View {
    var body: some View {
        List {
            Section("НИИ") {
                NavigationLink { RoadmapView() } label: { Label("План 90 дней", systemImage: "map.fill") }
                NavigationLink { PeopleView() } label: { Label("Люди и роли", systemImage: "person.2.fill") }
            }
            Section("Контент") {
                NavigationLink { CoursesView() } label: { Label("Курсы и уроки", systemImage: "graduationcap.fill") }
                NavigationLink { ProgramsView() } label: { Label("Программы и заявки", systemImage: "paperplane.fill") }
                NavigationLink { NewsView() } label: { Label("Новости", systemImage: "newspaper.fill") }
                NavigationLink { ShopView() } label: { Label("Мерч и заказы", systemImage: "tshirt.fill") }
            }
            Section("Как видят участники") {
                NavigationLink { HomeView() } label: { Label("Главная участника", systemImage: "eye") }
            }
        }
        .navigationTitle("Управление")
    }
}

struct PeopleView: View {
    @EnvironmentObject private var state: AppState
    @State private var people: [Profile] = []
    @State private var search = ""
    @State private var error: String?

    private var shown: [Profile] {
        search.isEmpty ? people : people.filter {
            $0.fullName.localizedCaseInsensitiveContains(search) || $0.phone.contains(search) || $0.organization.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(shown) { person in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(person.fullName).font(.headline)
                    if person.isFamily { Chip(text: "семья", color: .pink) }
                    Spacer()
                    Chip(text: person.role.title, color: person.role == .admin ? .niiFuchsia : .niiNavy)
                }
                Text([person.phone, person.organization].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .contextMenu {
                if person.userId != state.api.db.userID {
                    ForEach(Role.allCases) { role in
                        Button("Сделать: \(role.title)") { change { try await state.api.setRole(role, for: person.userId) } }
                    }
                }
                Button(person.isFamily ? "Убрать семейный доступ" : "Дать семейный доступ (Pro бесплатно)") {
                    change { try await state.api.setFamily(!person.isFamily, for: person.userId) }
                }
            }
        }
        .searchable(text: $search, prompt: "Имя, телефон, организация")
        .navigationTitle("Люди (\(people.count))")
        .safeAreaInset(edge: .bottom) {
            Text("Нажмите и удерживайте человека, чтобы сменить роль или дать семейный доступ.")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($error)
    }

    private func change(_ action: @escaping () async throws -> Void) {
        Task { await attempt($error) { try await action(); await load() } }
    }

    private func load() async {
        await attempt($error) { people = try await state.api.people() }
    }
}
