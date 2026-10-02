//
//  RootView.swift
//  NII App
//
//  Start screen, sign in / registration, and the tab bar for each role.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if !NIIConfig.isConfigured {
                ContentUnavailableView("Сервер не подключён", systemImage: "icloud.slash",
                                       description: Text("Впишите адрес и ключ Supabase в NIIConfig (см. README)."))
            } else if state.isStarting {
                SplashView()
            } else if !state.signedIn {
                WelcomeView()
            } else if let profile = state.profile {
                MainTabs(role: profile.role)
            } else {
                VStack(spacing: 16) {
                    if let message = state.profileError {
                        Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                        Text("Не удалось загрузить профиль").font(.headline)
                        Text(message).font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).textSelection(.enabled)
                    } else {
                        ProgressView()
                        Text("Загружаем профиль…").foregroundStyle(.secondary)
                    }
                    Button("Повторить") { Task { await state.loadProfile() } }
                    Button("Выйти", role: .destructive) { Task { await state.signOut() } }
                }
                .padding(24)
            }
        }
        .task { await state.start() }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient.nii.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "atom").font(.system(size: 72)).foregroundStyle(.white)
                Text("NII").font(.largeTitle.bold()).foregroundStyle(.white)
            }
        }
    }
}

struct MainTabs: View {
    let role: Role

    var body: some View {
        TabView {
            switch role {
            case .admin:
                NavigationStack { AdminDashboardView() }.tabItem { Label("Панель", systemImage: "chart.bar.fill") }
                NavigationStack { TasksView() }.tabItem { Label("Задачи", systemImage: "checklist") }
                NavigationStack { EventsView() }.tabItem { Label("События", systemImage: "calendar") }
                NavigationStack { ManageView() }.tabItem { Label("Управление", systemImage: "square.grid.2x2.fill") }
                NavigationStack { ProfileView() }.tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            case .team:
                NavigationStack { HomeView() }.tabItem { Label("Главная", systemImage: "house.fill") }
                NavigationStack { TasksView() }.tabItem { Label("Задачи", systemImage: "checklist") }
                NavigationStack { EventsView() }.tabItem { Label("Лаборатория", systemImage: "flask.fill") }
                NavigationStack { CoursesView() }.tabItem { Label("Курсы", systemImage: "graduationcap.fill") }
                NavigationStack { ProfileView() }.tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            case .user:
                NavigationStack { HomeView() }.tabItem { Label("Главная", systemImage: "house.fill") }
                NavigationStack { CoursesView() }.tabItem { Label("Курсы", systemImage: "graduationcap.fill") }
                NavigationStack { EventsView() }.tabItem { Label("События", systemImage: "calendar") }
                NavigationStack { ProgramsView() }.tabItem { Label("Программы", systemImage: "paperplane.fill") }
                NavigationStack { ProfileView() }.tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            }
        }
    }
}

// MARK: - Welcome / sign in / registration

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        ZStack {
            LinearGradient.nii.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "atom").font(.system(size: 80)).foregroundStyle(.white)
                Text("НИИ Инклюзивного\nИнжиниринга").font(.largeTitle.bold()).multilineTextAlignment(.center).foregroundStyle(.white)
                Text("Science × Technology × Inclusion × Impact").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                VStack(alignment: .leading, spacing: 10) {
                    Label("Курсы от исследователей НИИ", systemImage: "graduationcap.fill")
                    Label("Конференции и Zoom в один клик", systemImage: "person.3.fill")
                    Label("Онлайн-лаборатория и консультации", systemImage: "flask.fill")
                    Label("Стажировки, конкурсы, гранты", systemImage: "paperplane.fill")
                }
                .foregroundStyle(.white)
                .padding(.top, 8)
                Spacer()
                Button("Создать аккаунт") { showRegister = true }
                    .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.25)))
                Button("Войти") { showLogin = true }
                    .foregroundStyle(.white).font(.headline).padding(.bottom, 8)
            }
            .padding(24)
        }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showRegister) { RegisterView() }
    }
}

struct LoginView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var info: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Пароль", text: $password).textContentType(.password)
                }
                Section {
                    Button {
                        Task {
                            busy = true
                            await attempt($error) {
                                try await state.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
                                dismiss()
                            }
                            busy = false
                        }
                    } label: {
                        if busy { ProgressView() } else { Text("Войти").bold() }
                    }
                    .disabled(email.isEmpty || password.isEmpty || busy)

                    Button("Забыли пароль?") {
                        Task {
                            await attempt($error) {
                                try await state.api.db.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
                                info = "Мы отправили письмо для смены пароля на \(email)."
                            }
                        }
                    }
                    .disabled(email.isEmpty)
                }
                if let info { Section { Text(info).foregroundStyle(.green) } }
            }
            .navigationTitle("Вход")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .errorAlert($error)
        }
    }
}

struct RegisterView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var role: Role = .user
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var organization = ""
    @State private var accessCode = ""
    @State private var familyCode = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirmEmail = false

    private var emailValid: Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Кто вы?") {
                    Picker("Роль", selection: $role) {
                        ForEach(Role.allCases.reversed()) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text(role.hint).font(.footnote).foregroundStyle(.secondary)
                    if role != .user {
                        SecureField("Код доступа от организатора", text: $accessCode)
                    }
                }
                Section("Данные") {
                    TextField("Имя и фамилия", text: $fullName).textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Пароль (минимум 6 символов)", text: $password).textContentType(.newPassword)
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                    TextField("Организация", text: $organization)
                }
                Section {
                    DisclosureGroup("У меня есть семейный пароль") {
                        SecureField("Семейный пароль", text: $familyCode)
                    }
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if busy { ProgressView() } else { Text("Создать аккаунт").bold() }
                    }
                    .disabled(busy || fullName.isEmpty || !emailValid || password.count < 6 || (role != .user && accessCode.isEmpty))
                } footer: {
                    if !email.isEmpty && !emailValid { Text("Email должен быть вида name@gmail.com").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Регистрация")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .errorAlert($error)
            .alert("Подтвердите email", isPresented: $confirmEmail) {
                Button("OK") { dismiss() }
            } message: {
                Text("Мы отправили письмо на \(email). Нажмите ссылку в письме, затем войдите в приложение.")
            }
        }
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        let form = PendingRegistration(fullName: fullName.trimmingCharacters(in: .whitespaces), phone: phone,
                                       organization: organization, roleCode: role == .user ? "" : accessCode,
                                       familyCode: familyCode)
        await attempt($error) {
            let signedIn = try await state.register(form, email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
            if signedIn {
                if role != .user && state.role != role {
                    error = "Аккаунт создан как «Участник»: код доступа не подошёл. Его можно ввести позже в профиле."
                } else {
                    dismiss()
                }
            } else {
                confirmEmail = true
            }
        }
    }
}
