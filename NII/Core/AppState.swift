//
//  AppState.swift
//  NII App
//
//  Who is signed in, their profile and role, and whether they have Pro.
//

import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var isStarting = true
    /// Why the profile could not be loaded (shown on screen instead of an endless spinner)
    @Published private(set) var profileError: String?
    @Published var signedIn = false

    let api = API()
    let pro = ProStore()

    /// Pro: App Store subscription, family access or NII staff
    var hasPro: Bool {
        guard let profile else { return false }
        return profile.isStaff || profile.isFamily || pro.isActive
    }

    var role: Role { profile?.role ?? .user }

    func start() async {
        signedIn = api.db.session != nil
        if signedIn { await loadProfile() }
        isStarting = false
        await pro.load()
    }

    func loadProfile() async {
        profileError = nil
        do {
            if let existing = try await api.myProfile() {
                profile = existing
            } else {
                // First sign-in after email confirmation: create the profile from the registration form
                let pending = PendingRegistration.take(email: api.db.session?.email ?? "")
                try await api.createProfile(fullName: pending?.fullName ?? (api.db.session?.email ?? ""),
                                            phone: pending?.phone ?? "", organization: pending?.organization ?? "")
                if let code = pending?.roleCode, !code.isEmpty { _ = try? await api.claimRole(code: code) }
                if let code = pending?.familyCode, !code.isEmpty { try? await api.activateFamily(code: code) }
                profile = try await api.myProfile()
            }
        } catch NIIError.noSession {
            signedIn = false
            profile = nil
        } catch {
            // Keep the last known profile when offline, but say what went wrong
            if profile == nil {
                profileError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await api.db.signIn(email: email, password: password)
        signedIn = true
        await loadProfile()
    }

    /// Returns false when the user must confirm their email first
    func register(_ form: PendingRegistration, email: String, password: String) async throws -> Bool {
        PendingRegistration.save(form, email: email)
        var signedInNow = try await api.db.signUp(email: email, password: password, fullName: form.fullName)
        if !signedInNow {
            // The database confirms accounts at once, so signing in right away works
            signedInNow = (try? await api.db.signIn(email: email, password: password)) != nil
        }
        guard signedInNow else { return false }
        signedIn = true
        await loadProfile()
        return true
    }

    func deleteAccount() async throws {
        try await api.deleteAccount()
        profile = nil
        signedIn = false
    }

    func signOut() async {
        await api.db.signOut()
        profile = nil
        signedIn = false
    }
}

/// Registration details kept until the first sign-in (needed when email confirmation is on).
struct PendingRegistration: Codable {
    var fullName: String
    var phone: String
    var organization: String
    var roleCode: String
    var familyCode: String

    private static func account(_ email: String) -> String { "nii.pending." + email.lowercased() }

    static func save(_ value: PendingRegistration, email: String) {
        if let data = try? JSONEncoder().encode(value) { Keychain.write(data, account(email)) }
    }

    static func take(email: String) -> PendingRegistration? {
        guard let data = Keychain.read(account(email)) else { return nil }
        Keychain.delete(account(email))
        return try? JSONDecoder().decode(PendingRegistration.self, from: data)
    }
}
