//
//  HomeView.swift
//  NII App
//
//  Main screen for participants and team members.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var pro: ProStore

    @State private var myEvents: [NIIEvent] = []
    @State private var upcoming: [NIIEvent] = []
    @State private var myCourses: [Course] = []
    @State private var news: [NewsItem] = []
    @State private var programs: [Program] = []
    @State private var myTasks: [TaskItem] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero

                if !myTasks.isEmpty {
                    SectionTitle(title: "Мои задачи")
                    VStack(spacing: 0) {
                        ForEach(myTasks.prefix(5)) { task in
                            HStack {
                                Text(task.title)
                                Spacer()
                                Text(NIIDate.short(day: task.dueDate)).font(.caption)
                                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    .card()
                }

                SectionTitle(title: "Мои события")
                if myEvents.isEmpty {
                    EmptyCard(text: "Вы пока не записаны на мероприятия.")
                }
                ForEach(myEvents) { event in
                    NavigationLink { EventDetailView(event: event) } label: { EventRow(event: event, registered: true) }
                        .buttonStyle(.plain)
                }

                SectionTitle(title: "Мои курсы")
                if myCourses.isEmpty {
                    EmptyCard(text: "Вы ещё не записаны на курсы.")
                }
                ForEach(myCourses) { course in
                    NavigationLink { CourseDetailView(course: course) } label: { CourseRow(course: course) }
                        .buttonStyle(.plain)
                }

                if !upcoming.isEmpty {
                    SectionTitle(title: "Ближайшие конференции")
                    ForEach(upcoming) { event in
                        NavigationLink { EventDetailView(event: event) } label: { EventRow(event: event, registered: false) }
                            .buttonStyle(.plain)
                    }
                }

                if !programs.isEmpty {
                    SectionTitle(title: "Открытые программы")
                    ForEach(programs) { program in
                        NavigationLink { ProgramDetailView(program: program) } label: { ProgramRow(program: program, status: nil) }
                            .buttonStyle(.plain)
                    }
                }

                SectionTitle(title: "Новости НИИ")
                if news.isEmpty { EmptyCard(text: "Новостей пока нет.") }
                ForEach(news.prefix(3)) { item in
                    NewsCard(item: item)
                }
                NavigationLink("Все новости →") { NewsView() }.font(.subheadline.weight(.semibold))

                NavigationLink { ShopView() } label: {
                    Label("Мерч НИИ", systemImage: "tshirt.fill").font(.headline).card()
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Главная")
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Здравствуйте,").foregroundStyle(.white.opacity(0.8))
            Text(state.profile?.fullName ?? "").font(.title.bold()).foregroundStyle(.white)
            Text("Science creates opportunities for everyone.").font(.subheadline).foregroundStyle(.white.opacity(0.9))
            if state.hasPro {
                Text(proText).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.niiGold, in: Capsule()).foregroundStyle(.black)
            } else {
                NavigationLink { ProView() } label: {
                    Label("Подключить NII Pro — \(pro.priceText)/мес", systemImage: "star.fill")
                        .font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.niiGold, in: Capsule()).foregroundStyle(.black)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.nii, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var proText: String {
        if state.profile?.isFamily == true { return "PRO · семейный доступ" }
        if state.profile?.isStaff == true { return "PRO · команда НИИ" }
        return "PRO" + (pro.renewsOn.map { " · до \(NIIDate.short($0))" } ?? "")
    }

    private func load() async {
        await attempt($error) {
            let api = state.api
            async let events = api.events()
            async let regs = api.myRegistrations()
            async let courses = api.courses()
            async let enrolled = api.myEnrollments()
            async let newsList = api.news()
            async let programList = api.programs()
            let (allEvents, registered, allCourses, myEnrolled) = try await (events, regs, courses, enrolled)
            myEvents = allEvents.filter { registered.contains($0.id) }
            upcoming = Array(allEvents.filter { !registered.contains($0.id) && ($0.type == .conference || $0.type == .seminar) }.prefix(3))
            myCourses = allCourses.filter { myEnrolled.contains($0.id) }
            news = try await newsList.filter(\.published)
            programs = Array(try await programList.filter { $0.published && !$0.isClosed }.prefix(3))
            if state.role == .team {
                myTasks = try await api.tasks(openOnly: true).filter { $0.assignee == state.api.db.userID }
            }
        }
    }
}
