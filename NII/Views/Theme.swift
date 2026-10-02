//
//  Theme.swift
//  NII App
//

import SwiftUI

extension Color {
    static let niiNavy = Color(red: 0.12, green: 0.23, blue: 0.54)
    static let niiIndigo = Color(red: 0.26, green: 0.22, blue: 0.79)
    static let niiFuchsia = Color(red: 0.75, green: 0.15, blue: 0.83)
    static let niiGold = Color(red: 0.98, green: 0.75, blue: 0.14)
    static let niiBackground = Color(.systemGroupedBackground)
}

extension LinearGradient {
    static let nii = LinearGradient(colors: [.niiNavy, .niiIndigo, .niiFuchsia], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let pro = LinearGradient(colors: [.orange, .pink, .niiFuchsia], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }

    /// Shows an alert for an error message bound to a String?
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Ошибка", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

struct Chip: View {
    let text: String
    var color: Color = .niiNavy

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct ProBadge: View {
    var body: some View { Chip(text: "PRO", color: .orange) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .niiNavy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
    }
}

/// Picture from a link, with a gradient placeholder
struct RemoteImage: View {
    let url: String
    var height: CGFloat = 160
    var icon = "photo"

    var body: some View {
        ZStack {
            LinearGradient.nii
            if let link = URL(string: url), !url.isEmpty {
                AsyncImage(url: link) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: icon).font(.largeTitle).foregroundStyle(.white.opacity(0.8))
                    }
                }
            } else {
                Image(systemName: icon).font(.largeTitle).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

struct SectionTitle: View {
    let title: String
    var action: (String, () -> Void)?

    var body: some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            if let action {
                Button(action.0, action: action.1).font(.subheadline.weight(.semibold))
            }
        }
        .padding(.top, 8)
    }
}

struct EmptyCard: View {
    let text: String
    var body: some View {
        Text(text).foregroundStyle(.secondary).card()
    }
}

/// Runs an async action and turns errors into a message
@MainActor
func attempt(_ message: Binding<String?>, _ action: @escaping () async throws -> Void) async {
    do {
        try await action()
    } catch {
        message.wrappedValue = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
