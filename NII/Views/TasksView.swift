//
//  TasksView.swift
//  NII App
//
//  Organizer: all tasks, create and assign. Team: own tasks.
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var state: AppState

    enum Filter: String, CaseIterable, Identifiable {
        case today = "Сегодня", week = "Неделя", open = "Открытые", done = "Готово"
        var id: String { rawValue }
    }

    @State private var tasks: [TaskItem] = []
    @State private var people: [Profile] = []
    @State private var filter: Filter = .today
    @State private var showAdd = false
    @State private var error: String?

    private var isAdmin: Bool { state.role == .admin }

    private var filtered: [TaskItem] {
        let today = NIIDate.today
        let weekEnd = NIIDate.day(Date().addingTimeInterval(7 * 86400))
        return tasks.filter { task in
            switch filter {
            case .today: return !task.isDone && (task.dueDate.map { $0 <= today } ?? true)
            case .week: return !task.isDone && (task.dueDate.map { $0 >= today && $0 <= weekEnd } ?? false)
            case .open: return !task.isDone
            case .done: return task.isDone
            }
        }
    }

    var body: some View {
        List {
            Picker("Фильтр", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if filtered.isEmpty {
                Text(filter == .done ? "Пока ничего не выполнено." : "Задач нет 🎉").foregroundStyle(.secondary)
            }

            ForEach(filtered) { task in
                TaskRow(task: task, assigneeName: name(task.assignee), isAdmin: isAdmin, people: people) {
                    await reload()
                } onError: { error = $0 }
            }
        }
        .navigationTitle(isAdmin ? "Задачи НИИ" : "Мои задачи")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
            if isAdmin {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { RoadmapView() } label: { Label("План 90 дней", systemImage: "map") }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTaskView(people: people, isAdmin: isAdmin) { await reload() }
        }
        .refreshable { await reload() }
        .task { await reload() }
        .errorAlert($error)
    }

    private func name(_ id: UUID?) -> String? {
        guard let id, id != state.api.db.userID else { return nil }
        return people.first { $0.userId == id }?.fullName
    }

    private func reload() async {
        await attempt($error) {
            tasks = try await state.api.tasks()
            if people.isEmpty { people = try await state.api.people().filter(\.isStaff) }
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject private var state: AppState
    let task: TaskItem
    let assigneeName: String?
    let isAdmin: Bool
    let people: [Profile]
    let onChange: () async -> Void
    let onError: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Task { await run { try await state.api.setTask(task, done: !task.isDone) } }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(task.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text((task.priority == "high" ? "🔥 " : "") + task.title)
                    .strikethrough(task.isDone).foregroundStyle(task.isDone ? .secondary : .primary)
                if !task.description.isEmpty {
                    Text(task.description).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let label = task.weekLabel { Chip(text: label, color: .niiIndigo) }
                    Text(task.dueDate == nil ? "Без срока" : (task.isOverdue ? "Просрочено: " : "") + NIIDate.short(day: task.dueDate))
                        .font(.caption).foregroundStyle(task.isOverdue ? .red : .secondary)
                    if let assigneeName { Text("· 👤 \(assigneeName)").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if isAdmin {
                Button(role: .destructive) { Task { await run { try await state.api.deleteTask(task) } } } label: { Label("Удалить", systemImage: "trash") }
            }
            Button { Task { await run { try await state.api.moveTask(task, to: NIIDate.day(Date().addingTimeInterval(86400))) } } } label: {
                Label("На завтра", systemImage: "arrow.right.circle")
            }
            .tint(.orange)
        }
        .contextMenu {
            if isAdmin {
                Menu("Назначить") {
                    Button("Я") { Task { await run { try await state.api.assignTask(task, to: nil) } } }
                    ForEach(people) { person in
                        Button(person.fullName) { Task { await run { try await state.api.assignTask(task, to: person.userId) } } }
                    }
                }
            }
        }
    }

    private func run(_ action: @escaping () async throws -> Void) async {
        do {
            try await action()
            await onChange()
        } catch {
            onError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct AddTaskView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let people: [Profile]
    let isAdmin: Bool
    let onSaved: () async -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var hasDue = true
    @State private var due = Date()
    @State private var priority = "normal"
    @State private var assignee: UUID?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Что нужно сделать?", text: $title)
                TextField("Описание", text: $details, axis: .vertical)
                Toggle("Срок", isOn: $hasDue)
                if hasDue { DatePicker("Дата", selection: $due, displayedComponents: .date) }
                Picker("Приоритет", selection: $priority) {
                    Text("Обычный").tag("normal")
                    Text("🔥 Высокий").tag("high")
                    Text("Низкий").tag("low")
                }
                if isAdmin {
                    Picker("Исполнитель", selection: $assignee) {
                        Text("Я").tag(UUID?.none)
                        ForEach(people.filter { $0.userId != state.api.db.userID }) { Text($0.fullName).tag(Optional($0.userId)) }
                    }
                }
            }
            .navigationTitle("Новая задача")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task {
                            await attempt($error) {
                                let owner = isAdmin ? assignee : state.api.db.userID
                                try await state.api.addTask(title: title, description: details,
                                                            due: hasDue ? NIIDate.day(due) : nil,
                                                            priority: priority, assignee: owner)
                                await onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .errorAlert($error)
        }
    }
}
