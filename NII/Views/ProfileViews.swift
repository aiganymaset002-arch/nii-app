//
//  ProfileViews.swift
//  NII App
//
//  NII Pro subscription screen and the profile: details, access codes, my applications,
//  my orders, sign out and account deletion (required by the App Store).
//

import StoreKit
import SwiftUI

struct ProView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var pro: ProStore

    private let perks: [(String, String, String)] = [
        ("graduationcap.fill", "Все PRO-курсы", "Видеоуроки, материалы и сертификаты НИИ"),
        ("person.3.fill", "Закрытые конференции и семинары", "Запись на PRO-события и ссылки Zoom"),
        ("flask.fill", "Онлайн-лаборатория", "Исследовательские сессии с командой НИИ"),
        ("star.fill", "Поддержка науки", "Подписка помогает НИИ запускать новые программы"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "atom").font(.system(size: 54))
                    Text("NII Pro").font(.largeTitle.bold())
                    Text("Ежемесячная подписка").font(.subheadline).opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(LinearGradient.pro, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(perks, id: \.1) { icon, title, text in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon).font(.title3).foregroundStyle(.orange).frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.headline)
                                Text(text).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .card()

                if state.profile?.isFamily == true || state.profile?.isStaff == true {
                    Label(state.profile?.isFamily == true ? "У вас семейный доступ — всё бесплатно" : "У команды НИИ Pro включён",
                          systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(.green).card()
                } else if pro.isActive {
                    VStack(spacing: 6) {
                        Label("NII Pro активен", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(.green)
                        if let date = pro.renewsOn { Text("Продлится " + NIIDate.short(date)).font(.subheadline) }
                    }
                    .card()
                    ManageSubscriptionButton()
                } else {
                    Button { Task { await pro.buy() } } label: {
                        if pro.isBusy { ProgressView().tint(.white) } else { Text("Подписаться за \(pro.priceText) в месяц") }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .orange))
                    .disabled(pro.isBusy)
                }

                Button("Восстановить покупки") { Task { await pro.restore() } }
                    .font(.subheadline)
                    .disabled(pro.isBusy)

                Text("Подписка продлевается автоматически каждый месяц, пока её не отменить. Оплата списывается с Apple ID при подтверждении покупки. Отменить можно в любой момент в Настройки → Apple ID → Подписки не позднее чем за 24 часа до конца периода.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Link("Условия использования", destination: NIIConfig.termsURL)
                    Link("Конфиденциальность", destination: NIIConfig.privacyURL)
                }
                .font(.caption)
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("NII Pro")
        .navigationBarTitleDisplayMode(.inline)
        .alert("NII Pro", isPresented: Binding(get: { pro.message != nil }, set: { if !$0 { pro.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pro.message ?? "")
        }
        .task { if pro.product == nil { await pro.load() } }
    }
}

struct ManageSubscriptionButton: View {
    @State private var showing = false
    var body: some View {
        Button("Управлять подпиской") { showing = true }
            .manageSubscriptionsSheet(isPresented: $showing)
    }
}

struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var pro: ProStore

    @State private var fullName = ""
    @State private var phone = ""
    @State private var organization = ""
    @State private var roleCode = ""
    @State private var familyCode = ""
    @State private var applications: [Application] = []
    @State private var programs: [Int: Program] = [:]
    @State private var confirmDelete = false
    @State private var info: String?
    @State private var error: String?

    private var changed: Bool {
        guard let p = state.profile else { return false }
        return p.fullName != fullName || p.phone != phone || p.organization != organization
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Text(initials)
                        .font(.title2.bold()).foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(LinearGradient.nii, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.profile?.fullName ?? "").font(.headline)
                        Text(state.api.db.session?.email ?? "").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Chip(text: state.role.title, color: state.role == .admin ? .niiFuchsia : .niiNavy)
                            if state.hasPro { ProBadge() }
                        }
                    }
                }
            }

            Section("NII Pro") {
                NavigationLink { ProView() } label: {
                    Label(state.hasPro ? "Pro подключён" : "Подключить NII Pro — \(pro.priceText)/мес", systemImage: "star.fill")
                }
            }

            Section("Мои данные") {
                TextField("ФИО", text: $fullName).textContentType(.name)
                TextField("Телефон", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                TextField("Организация / вуз", text: $organization)
                if changed {
                    Button("Сохранить") {
                        Task {
                            await attempt($error) {
                                try await state.api.updateProfile(fullName: fullName.trimmingCharacters(in: .whitespaces),
                                                                  phone: phone, organization: organization)
                                await state.loadProfile()
                                info = "Сохранено"
                            }
                        }
                    }
                    .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if state.role == .user {
                Section("Мои заявки") {
                    if applications.isEmpty { Text("Вы ещё не подавали заявки").foregroundStyle(.secondary) }
                    ForEach(applications) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(programs[app.programId]?.title ?? "Программа").font(.subheadline.weight(.semibold))
                                Spacer()
                                ApplicationStatusChip(application: app)
                            }
                            if !app.adminNote.isEmpty { Text(app.adminNote).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }

            Section {
                NavigationLink { ShopView() } label: { Label("Мерч НИИ и мои заказы", systemImage: "tshirt.fill") }
                NavigationLink { NewsView() } label: { Label("Новости", systemImage: "newspaper.fill") }
            }

            Section {
                if state.role == .user {
                    SecureField("Код команды или организатора", text: $roleCode)
                    Button("Применить код") {
                        Task {
                            await attempt($error) {
                                let role = try await state.api.claimRole(code: roleCode.trimmingCharacters(in: .whitespaces))
                                roleCode = ""
                                await state.loadProfile()
                                info = "Ваша роль: \(role.title)"
                            }
                        }
                    }
                    .disabled(roleCode.isEmpty)
                }
                if state.profile?.isFamily != true {
                    SecureField("Семейный пароль", text: $familyCode)
                    Button("Активировать семейный доступ") {
                        Task {
                            await attempt($error) {
                                try await state.api.activateFamily(code: familyCode)
                                familyCode = ""
                                await state.loadProfile()
                                info = "Семейный доступ включён — всё бесплатно"
                            }
                        }
                    }
                    .disabled(familyCode.isEmpty)
                } else {
                    Label("Семейный доступ включён", systemImage: "heart.fill").foregroundStyle(.pink)
                }
            } header: {
                Text("Коды доступа")
            }

            Section {
                Link(destination: NIIConfig.privacyURL) { Label("Политика конфиденциальности", systemImage: "hand.raised.fill") }
                Button("Выйти") { Task { await state.signOut() } }
                Button("Удалить аккаунт", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("НИИ Инклюзивного Инжиниринга · Science creates opportunities for everyone.")
            }
        }
        .navigationTitle("Профиль")
        .confirmationDialog("Удалить аккаунт навсегда?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить аккаунт и все данные", role: .destructive) {
                Task { await attempt($error) { try await state.deleteAccount() } }
            }
        } message: {
            Text("Профиль, записи на события, курсы, заявки и заказы будут удалены. Подписку App Store отмените отдельно в настройках Apple ID.")
        }
        .alert("Готово", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(info ?? "") }
        .errorAlert($error)
        .onAppear(perform: fill)
        .onChange(of: state.profile) { fill() }
        .task { await load() }
        .refreshable { await state.loadProfile(); await load() }
    }

    private var initials: String {
        let parts = (state.profile?.fullName ?? "").split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "N" : letters.uppercased()
    }

    private func fill() {
        guard let p = state.profile else { return }
        fullName = p.fullName
        phone = p.phone
        organization = p.organization
    }

    private func load() async {
        guard state.role == .user else { return }
        applications = (try? await state.api.myApplications()) ?? []
        let all = (try? await state.api.programs()) ?? []
        programs = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
}
