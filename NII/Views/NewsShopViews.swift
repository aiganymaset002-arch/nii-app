//
//  NewsShopViews.swift
//  NII App
//
//  News feed and NII merch. Merch is a physical product, so it is paid by Kaspi / bank
//  transfer (not through the App Store); the organizer confirms the payment.
//

import SwiftUI

// MARK: - News

struct NewsView: View {
    @EnvironmentObject private var state: AppState

    @State private var items: [NewsItem] = []
    @State private var editing: NewsItem?
    @State private var adding = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if items.isEmpty { EmptyCard(text: "Новостей пока нет") }
                ForEach(items) { item in
                    NewsCard(item: item)
                        .contextMenu {
                            if state.role == .admin {
                                Button("Изменить", systemImage: "pencil") { editing = item }
                                Button("Удалить", systemImage: "trash", role: .destructive) {
                                    Task { await attempt($error) { try await state.api.deleteNews(item.id); await load() } }
                                }
                            }
                        }
                }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Новости")
        .toolbar {
            if state.role == .admin {
                Button { adding = true } label: { Image(systemName: "square.and.pencil") }
            }
        }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) { NewsEditor(item: nil) }
        .sheet(item: $editing, onDismiss: { Task { await load() } }) { NewsEditor(item: $0) }
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        await attempt($error) { items = try await state.api.news() }
    }
}

struct NewsCard: View {
    let item: NewsItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !item.imageUrl.isEmpty {
                RemoteImage(url: item.imageUrl, height: 160, icon: "newspaper.fill")
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(NIIDate.short(item.createdAt)).font(.caption).foregroundStyle(.secondary)
                    if !item.published { Chip(text: "черновик", color: .gray) }
                }
                Text(item.title).font(.headline)
                Text(.init(item.body))
                    .font(.subheadline)
                    .lineLimit(expanded ? nil : 4)
                    .textSelection(.enabled)
                if item.body.count > 200 {
                    Button(expanded ? "Свернуть" : "Читать полностью") { withAnimation { expanded.toggle() } }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct NewsEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let item: NewsItem?
    @State private var draft = API.NewsDraft()
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Заголовок", text: $draft.title)
                    TextField("Ссылка на картинку (необязательно)", text: $draft.imageUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Текст") {
                    TextField("Текст новости", text: $draft.body, axis: .vertical).lineLimit(8...30)
                }
                Section { Toggle("Опубликовать", isOn: $draft.published) }
            }
            .navigationTitle(item == nil ? "Новая новость" : "Изменить новость")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saving = true
                        Task {
                            await attempt($error) { try await state.api.saveNews(draft, id: item?.id); dismiss() }
                            saving = false
                        }
                    }
                    .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .errorAlert($error)
            .onAppear {
                if let item {
                    draft = API.NewsDraft(title: item.title, body: item.body, imageUrl: item.imageUrl, published: item.published)
                }
            }
        }
    }
}

// MARK: - Merch

struct ShopView: View {
    @EnvironmentObject private var state: AppState

    @State private var products: [MerchItem] = []
    @State private var orders: [Order] = []
    @State private var buying: MerchItem?
    @State private var editing: MerchItem?
    @State private var adding = false
    @State private var placed: Order?
    @State private var error: String?

    private var isAdmin: Bool { state.role == .admin }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if products.isEmpty { EmptyCard(text: "Товары скоро появятся") }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(products) { item in
                        Button { if isAdmin { editing = item } else { buying = item } } label: { productCard(item) }
                            .buttonStyle(.plain)
                    }
                }

                SectionTitle(title: isAdmin ? "Все заказы" : "Мои заказы")
                if orders.isEmpty { EmptyCard(text: "Заказов пока нет") }
                ForEach(orders) { order in orderRow(order) }
            }
            .padding()
        }
        .background(Color.niiBackground)
        .navigationTitle("Мерч НИИ")
        .toolbar {
            if isAdmin { Button { adding = true } label: { Image(systemName: "plus") } }
        }
        .sheet(item: $buying, onDismiss: { Task { await load() } }) { item in
            OrderSheet(item: item) { placed = $0 }
        }
        .sheet(item: $editing, onDismiss: { Task { await load() } }) { ProductEditor(item: $0) }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) { ProductEditor(item: nil) }
        .alert("Заказ №\(placed?.id ?? 0) создан", isPresented: Binding(get: { placed != nil }, set: { if !$0 { placed = nil } })) {
            Button("Скопировать номер Kaspi") { UIPasteboard.general.string = "+77714731852" }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Сумма: \(placed?.amount.usd ?? "") (в тенге по курсу).\n\n" + NIIConfig.merchPaymentInfo)
        }
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private func productCard(_ item: MerchItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: item.imageUrl, height: 120, icon: "tshirt.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                HStack {
                    Text(item.price.usd).font(.headline).foregroundStyle(.niiIndigo)
                    if !item.active { Chip(text: "скрыт", color: .gray) }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func orderRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("№\(order.id) · \(order.title)").font(.headline)
                Spacer()
                Chip(text: order.statusTitle, color: order.status == "new" ? .orange : order.status == "cancelled" ? .gray : .green)
            }
            Text(order.amount.usd + " · " + NIIDate.dateTime(order.createdAt)).font(.caption).foregroundStyle(.secondary)
            if !order.note.isEmpty { Text(order.note).font(.subheadline) }
            if isAdmin {
                HStack {
                    ForEach([("paid", "Оплачен"), ("shipped", "Выдан"), ("cancelled", "Отменить")], id: \.0) { status, title in
                        Button(title) {
                            Task { await attempt($error) { try await state.api.setOrder(order, status: status); await load() } }
                        }
                        .buttonStyle(.bordered)
                        .disabled(order.status == status)
                    }
                }
                .font(.caption)
            } else if order.status == "new" {
                Text("Оплатите переводом на Kaspi +7 771 473 18 52, в комментарии укажите №\(order.id).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func load() async {
        await attempt($error) {
            products = try await state.api.products()
            if isAdmin { orders = try await state.api.allOrders() } else { orders = try await state.api.myOrders() }
        }
    }
}

struct OrderSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let item: MerchItem
    var onPlaced: (Order) -> Void
    @State private var note = ""
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RemoteImage(url: item.imageUrl, height: 220, icon: "tshirt.fill")
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(item.title).font(.title2.bold())
                    Text(item.price.usd).font(.title3.bold()).foregroundStyle(.niiIndigo)
                    if !item.description.isEmpty { Text(item.description).foregroundStyle(.secondary) }
                    TextField("Размер, цвет, как получить", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                    Text(NIIConfig.merchPaymentInfo).font(.footnote).foregroundStyle(.secondary).card()
                    Button {
                        sending = true
                        Task {
                            await attempt($error) {
                                let order = try await state.api.order(product: item.id, note: note)
                                dismiss()
                                onPlaced(order)
                            }
                            sending = false
                        }
                    } label: {
                        if sending { ProgressView().tint(.white) } else { Text("Оформить заказ") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(sending)
                }
                .padding()
            }
            .navigationTitle("Заказ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .errorAlert($error)
        }
    }
}

struct ProductEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let item: MerchItem?
    @State private var draft = API.ProductDraft()
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $draft.title)
                    TextField("Описание", text: $draft.description, axis: .vertical).lineLimit(2...6)
                    TextField("Ссылка на фото", text: $draft.imageUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    HStack {
                        Text("Цена, $")
                        TextField("0", value: $draft.price, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Toggle("В продаже", isOn: $draft.active)
                }
                if let item {
                    Section {
                        Button("Удалить товар", role: .destructive) {
                            Task { await attempt($error) { try await state.api.deleteProduct(item.id); dismiss() } }
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "Новый товар" : "Изменить товар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saving = true
                        Task {
                            await attempt($error) { try await state.api.saveProduct(draft, id: item?.id); dismiss() }
                            saving = false
                        }
                    }
                    .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty || draft.price < 0)
                }
            }
            .errorAlert($error)
            .onAppear {
                if let item {
                    draft = API.ProductDraft(title: item.title, description: item.description, imageUrl: item.imageUrl,
                                             price: item.price, active: item.active)
                }
            }
        }
    }
}
