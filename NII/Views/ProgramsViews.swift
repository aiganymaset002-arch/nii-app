//
//  ProgramsViews.swift
//  NII App
//
//  Programs (internships, grants, research groups): apply, track the status.
//  The organizer publishes programs and reviews applications.
//

import SwiftUI

struct ProgramsView: View {
    @EnvironmentObject private var state: AppState

    @State private var programs: [Program] = []
    @State private var mine: [Application] = []
    @State private var editing = false
    @State private var error: String?

    var body: some View {
        List {
            if programs.isEmpty {
                Text("Программ пока нет").foregroundStyle(.secondary)
            }
            ForEach(programs) { program in
                NavigationLink { ProgramDetailView(program: program) } label: {
                    ProgramRow(program: program, status: mine.first { $0.programId == program.id })
                }
            }
        }
        .navigationTitle("Программы")
        .toolbar {
            if state.role == .admin {
                Button { editing = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { ProgramEditor(program: nil) }
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        await attempt($error) {
            async let p = state.api.programs()
            async let m = state.api.myApplications()
            programs = try await p
            mine = (try? await m) ?? []
        }
    }
}

struct ProgramRow: View {
    let program: Program
    let status: Application?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Chip(text: program.kind, color: .niiIndigo)
                if !program.published { Chip(text: "черновик", color: .gray) }
                if program.isClosed { Chip(text: "приём закрыт", color: .gray) }
            }
            Text(program.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
            HStack {
                if let deadline = program.deadline {
                    Text("до " + NIIDate.short(day: deadline)).font(.caption).foregroundStyle(.secondary)
                }
                if let status { ApplicationStatusChip(application: status) }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ApplicationStatusChip: View {
    let application: Application
    var body: some View {
        Chip(text: application.statusTitle,
             color: application.status == "accepted" ? .green : application.status == "rejected" ? .red : .orange)
    }
}

struct ProgramDetailView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State var program: Program
    @State private var mine: Application?
    @State private var applications: [Application] = []
    @State private var people: [UUID: Profile] = [:]
    @State private var motivation = ""
    @State private var link = ""
    @State private var editing = false
    @State private var reviewing: Application?
    @State private var sending = false
    @State private var error: String?

    private var isAdmin: Bool { state.role == .admin }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(program.kind.uppercased()).font(.caption.weight(.bold)).tracking(1)
                    Text(program.title).font(.title.bold())
                    if let deadline = program.deadline {
                        Text("Приём заявок до " + NIIDate.short(day: deadline)).font(.subheadline)
                    }
                }
                .foregroundStyle(.white)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient.nii, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if !program.description.isEmpty { Text(program.description).card() }

                if let mine {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("Ваша заявка").font(.headline); Spacer(); ApplicationStatusChip(application: mine) }
                        Text("Отправлена " + NIIDate.dateTime(mine.createdAt)).font(.caption).foregroundStyle(.secondary)
                        if !mine.adminNote.isEmpty {
                            Text("Ответ организатора: " + mine.adminNote).font(.subheadline)
                        }
                    }
                    .card()
                } else if program.isClosed {
                    EmptyCard(text: "Приём заявок завершён")
                } else if !isAdmin {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Подать заявку").font(.headline)
                        TextField("Почему вы хотите участвовать? Ваш опыт и цели", text: $motivation, axis: .vertical)
                            .lineLimit(4...10)
                            .textFieldStyle(.roundedBorder)
                        TextField("Ссылка на резюме / портфолио (необязательно)", text: $link)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Button { Task { await send() } } label: {
                            if sending { ProgressView().tint(.white) } else { Text("Отправить заявку") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(sending || motivation.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                    }
                    .card()
                }

                if isAdmin {
                    SectionTitle(title: "Заявки (\(applications.count))")
                    if applications.isEmpty { EmptyCard(text: "Заявок пока нет") }
                    ForEach(applications) { app in
                        Button { reviewing = app } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(people[app.userId]?.fullName ?? "Участник").font(.headline)
                                    Spacer()
                                    ApplicationStatusChip(application: app)
                                }
                                Text(app.motivation).font(.subheadline).lineLimit(3).multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(.primary)
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Программа")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAdmin {
                Menu {
                    Button("Изменить", systemImage: "pencil") { editing = true }
                    Button("Удалить", systemImage: "trash", role: .destructive) {
                        Task { await attempt($error) { try await state.api.deleteProgram(program.id); dismiss() } }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { await reloadProgram() } }) { ProgramEditor(program: program) }
        .sheet(item: $reviewing, onDismiss: { Task { await load() } }) { app in
            ApplicationReview(application: app, person: people[app.userId])
        }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($error)
    }

    private func send() async {
        sending = true
        defer { sending = false }
        await attempt($error) {
            try await state.api.apply(program: program.id,
                                      motivation: motivation.trimmingCharacters(in: .whitespacesAndNewlines),
                                      link: link.trimmingCharacters(in: .whitespaces))
            await load()
        }
    }

    private func reloadProgram() async {
        if let fresh = try? await state.api.programs().first(where: { $0.id == program.id }) { program = fresh }
        await load()
    }

    private func load() async {
        mine = try? await state.api.myApplications().first { $0.programId == program.id }
        if isAdmin {
            applications = (try? await state.api.applications(program: program.id)) ?? []
            let all = (try? await state.api.people()) ?? []
            people = Dictionary(all.map { ($0.userId, $0) }, uniquingKeysWith: { a, _ in a })
        }
    }
}

struct ApplicationReview: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let application: Application
    let person: Profile?
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Кандидат") {
                    Text(person?.fullName ?? "Участник").font(.headline)
                    if let org = person?.organization, !org.isEmpty { Text(org) }
                    if let phone = person?.phone, !phone.isEmpty, let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                        Button(phone) { openURL(url) }
                    }
                }
                Section("Мотивация") { Text(application.motivation).textSelection(.enabled) }
                if let url = URL(string: application.link), !application.link.isEmpty {
                    Section("Ссылка") { Button(application.link) { openURL(url) } }
                }
                Section("Ответ кандидату") {
                    TextField("Комментарий (увидит кандидат)", text: $note, axis: .vertical).lineLimit(2...6)
                }
                Section {
                    Button("Принять") { Task { await decide("accepted") } }.foregroundStyle(.green)
                    Button("Отклонить", role: .destructive) { Task { await decide("rejected") } }
                    Button("Вернуть на рассмотрение") { Task { await decide("new") } }
                }
            }
            .navigationTitle(application.statusTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .onAppear { note = application.adminNote }
            .errorAlert($error)
        }
    }

    private func decide(_ status: String) async {
        await attempt($error) {
            try await state.api.decide(application, status: status, note: note)
            dismiss()
        }
    }
}

struct ProgramEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let program: Program?
    @State private var draft = API.ProgramDraft()
    @State private var hasDeadline = true
    @State private var deadline = Date().addingTimeInterval(30 * 86400)
    @State private var saving = false
    @State private var error: String?

    private let kinds = ["Стажировка", "Грант", "Исследовательская группа", "Акселератор", "Программа"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Вид", selection: $draft.kind) {
                        ForEach(Array(Set(kinds + [draft.kind])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Название", text: $draft.title)
                    TextField("Описание: условия, требования, что получит участник", text: $draft.description, axis: .vertical)
                        .lineLimit(4...12)
                }
                Section {
                    Toggle("Есть срок подачи", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Подать до", selection: $deadline, displayedComponents: .date)
                            .environment(\.timeZone, NIIDate.timeZone)
                    }
                    Toggle("Опубликовано", isOn: $draft.published)
                }
            }
            .navigationTitle(program == nil ? "Новая программа" : "Изменить программу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .errorAlert($error)
            .onAppear {
                guard let program else { return }
                draft = API.ProgramDraft(kind: program.kind, title: program.title, description: program.description,
                                         deadline: program.deadline, published: program.published)
                hasDeadline = program.deadline != nil
                if let date = NIIDate.dayDate(program.deadline) { deadline = date }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        draft.deadline = hasDeadline ? NIIDate.day(deadline) : nil
        await attempt($error) {
            try await state.api.saveProgram(draft, id: program?.id)
            dismiss()
        }
    }
}
