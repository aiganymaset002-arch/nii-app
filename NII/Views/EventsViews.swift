//
//  EventsViews.swift
//  NII App
//
//  Conferences, seminars, online lab and meetings: list, details with Zoom, registration,
//  and the editor for the organizer (any type) and the team (lab and meetings).
//

import SwiftUI

struct EventsView: View {
    @EnvironmentObject private var state: AppState

    @State private var events: [NIIEvent] = []
    @State private var counts: [Int: Int] = [:]
    @State private var mine: Set<Int> = []
    @State private var kind: EventKind?
    @State private var showPast = false
    @State private var editing = false
    @State private var error: String?

    private var shown: [NIIEvent] {
        events.filter { kind == nil || $0.type == kind }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filterChip(nil, "Все")
                        ForEach(EventKind.allCases) { filterChip($0, $0.title) }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                Toggle("Показать прошедшие", isOn: $showPast)
            }

            if shown.isEmpty {
                Text("Событий пока нет").foregroundStyle(.secondary)
            }
            ForEach(shown) { event in
                NavigationLink { EventDetailView(event: event) } label: {
                    EventRow(event: event, registered: mine.contains(event.id), taken: counts[event.id])
                }
            }
        }
        .navigationTitle(state.role == .team ? "Лаборатория и встречи" : "События")
        .toolbar {
            if state.profile?.isStaff == true {
                Button { editing = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) {
            EventEditor(event: nil)
        }
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: showPast) { Task { await load() } }
        .errorAlert($error)
    }

    private func filterChip(_ value: EventKind?, _ title: String) -> some View {
        Button { kind = value } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(kind == value ? Color.niiNavy : Color.niiNavy.opacity(0.1), in: Capsule())
                .foregroundStyle(kind == value ? .white : Color.niiNavy)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        await attempt($error) {
            async let e = state.api.events(includePast: showPast)
            async let c = state.api.eventCounts()
            async let m = state.api.myRegistrations()
            events = try await e
            counts = (try? await c) ?? [:]
            mine = (try? await m) ?? []
            if showPast { events.reverse() }
        }
    }
}

struct EventRow: View {
    let event: NIIEvent
    var registered: Bool
    var taken: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(NIIDate.short(event.startsAt).prefix(5)).font(.headline)
                Text(NIIDate.time(event.startsAt)).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 56)
            .padding(.vertical, 6)
            .background(Color.niiNavy.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Label(event.type.title, systemImage: event.type.icon).font(.caption).foregroundStyle(Color.niiIndigo)
                    if event.proOnly { ProBadge() }
                    if !event.published { Chip(text: "черновик", color: .gray) }
                }
                Text(event.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if event.isLive { Chip(text: "идёт сейчас", color: .red) }
                    if registered { Chip(text: "вы записаны", color: .green) }
                    if event.capacity > 0, let taken {
                        Text("\(taken)/\(event.capacity) мест").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct EventDetailView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var pro: ProStore // refreshes Pro gating after a purchase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State var event: NIIEvent
    @State private var registered = false
    @State private var taken = 0
    @State private var zoom: String?
    @State private var attendees: [Profile] = []
    @State private var editing = false
    @State private var showPro = false
    @State private var busy = false
    @State private var error: String?

    private var canManage: Bool {
        switch state.role {
        case .admin: return true
        case .team: return event.type == .lab || event.type == .meeting
        case .user: return false
        }
    }

    private var isFull: Bool { event.capacity > 0 && taken >= event.capacity }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(event.type.title, systemImage: event.type.icon).font(.subheadline.weight(.semibold))
                    Text(event.title).font(.title.bold())
                    HStack { if event.proOnly { Chip(text: "PRO", color: .white) }; if event.isLive { Chip(text: "идёт сейчас", color: .white) } }
                }
                .foregroundStyle(.white)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient.nii, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    info("calendar", NIIDate.dateTime(event.startsAt) + " – " + NIIDate.time(event.endsAt) + " (Астана)")
                    info("mappin.and.ellipse", event.location)
                    if event.capacity > 0 { info("person.2", "Мест: \(max(0, event.capacity - taken)) из \(event.capacity)") }
                }
                .card()

                if !event.description.isEmpty {
                    Text(event.description).card()
                }

                actions

                if canManage {
                    SectionTitle(title: "Участники (\(attendees.count))")
                    if attendees.isEmpty { EmptyCard(text: "Пока никто не записался") }
                    ForEach(attendees) { person in
                        VStack(alignment: .leading) {
                            Text(person.fullName).font(.headline)
                            Text([person.organization, person.phone].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .card()
                    }
                }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle(event.type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManage {
                Menu {
                    Button("Изменить", systemImage: "pencil") { editing = true }
                    Button("Удалить", systemImage: "trash", role: .destructive) {
                        Task { await attempt($error) { try await state.api.deleteEvent(event.id); dismiss() } }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { await reloadEvent() } }) {
            EventEditor(event: event)
        }
        .sheet(isPresented: $showPro) { NavigationStack { ProView() } }
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($error)
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 10) {
            if let zoom, let url = URL(string: zoom), registered || state.profile?.isStaff == true {
                Button { openURL(url) } label: { Label("Войти в Zoom", systemImage: "video.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: event.isLive ? .red : .niiIndigo))
                ShareLink(item: url) { Label("Поделиться ссылкой", systemImage: "square.and.arrow.up") }
                    .font(.subheadline)
            }

            if event.isPast {
                Text("Событие завершилось").foregroundStyle(.secondary)
            } else if registered {
                Text("Вы записаны ✅ Ссылка на Zoom появится выше.").font(.subheadline)
                Button("Отменить запись", role: .destructive) {
                    Task { await toggle(on: false) }
                }
            } else if event.proOnly && !state.hasPro {
                Button { showPro = true } label: { Label("Доступно с NII Pro", systemImage: "lock.fill") }
                    .buttonStyle(PrimaryButtonStyle(color: .orange))
            } else if isFull {
                Text("Мест больше нет").foregroundStyle(.secondary)
            } else {
                Button { Task { await toggle(on: true) } } label: {
                    if busy { ProgressView().tint(.white) } else { Text("Записаться") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func info(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.subheadline)
    }

    private func toggle(on: Bool) async {
        busy = true
        defer { busy = false }
        await attempt($error) {
            if on { try await state.api.register(event: event.id) } else { try await state.api.cancel(event: event.id) }
        }
        await load()
    }

    private func reloadEvent() async {
        if let fresh = try? await state.api.events(includePast: true).first(where: { $0.id == event.id }) {
            event = fresh
        }
        await load()
    }

    private func load() async {
        async let mine = state.api.myRegistrations()
        async let counts = state.api.eventCounts()
        registered = (try? await mine)?.contains(event.id) ?? false
        taken = (try? await counts)?[event.id] ?? 0
        zoom = try? await state.api.zoomLink(event: event.id)
        if canManage { attendees = (try? await state.api.attendees(event: event.id)) ?? [] }
    }
}

struct EventEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let event: NIIEvent?
    @State private var draft = API.EventDraft()
    @State private var zoom = ""
    @State private var limited = false
    @State private var saving = false
    @State private var error: String?

    /// The team can create only online-lab sessions and meetings (checked by the database too)
    private var kinds: [EventKind] {
        state.role == .admin ? EventKind.allCases : [.lab, .meeting]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $draft.type) {
                        ForEach(kinds) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    TextField("Название", text: $draft.title)
                    TextField("Описание: программа, спикеры, для кого", text: $draft.description, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section("Когда и где") {
                    DatePicker("Начало", selection: $draft.startsAt)
                        .environment(\.timeZone, NIIDate.timeZone)
                    Stepper("Длительность: \(draft.durationMin) мин", value: $draft.durationMin, in: 15...600, step: 15)
                    TextField("Место", text: $draft.location)
                    TextField("Ссылка Zoom (видна только записавшимся)", text: $zoom)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Доступ") {
                    Toggle("Ограничить число мест", isOn: $limited)
                    if limited {
                        Stepper("Мест: \(draft.capacity)", value: $draft.capacity, in: 1...10000)
                    }
                    Toggle("Только для NII Pro", isOn: $draft.proOnly)
                    Toggle("Опубликовано", isOn: $draft.published)
                }
            }
            .navigationTitle(event == nil ? "Новое событие" : "Изменить событие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .errorAlert($error)
            .task { await fill() }
        }
    }

    private func fill() async {
        guard let event else {
            if !kinds.contains(draft.type) { draft.type = .lab }
            if state.role == .team { draft.host = state.profile?.userId }
            return
        }
        draft = API.EventDraft(type: event.type, title: event.title, description: event.description,
                               startsAt: event.startsAt, durationMin: event.durationMin, location: event.location,
                               capacity: event.capacity, proOnly: event.proOnly, published: event.published, host: event.host)
        limited = event.capacity > 0
        zoom = (try? await state.api.zoomLink(event: event.id)) ?? ""
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if !limited { draft.capacity = 0 }
        draft.title = draft.title.trimmingCharacters(in: .whitespaces)
        await attempt($error) {
            try await state.api.saveEvent(draft, id: event?.id, zoom: zoom.trimmingCharacters(in: .whitespaces))
            dismiss()
        }
    }
}
