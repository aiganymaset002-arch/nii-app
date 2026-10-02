//
//  Supabase.swift
//  NII App
//
//  Talks to Supabase directly over REST (Auth + PostgREST), no third-party packages.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var userID: UUID
    var email: String
    var expiresAt: Date
}

enum NIIError: LocalizedError, Equatable {
    case notConfigured
    case http(Int, String)
    case confirmEmail
    case noSession

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Приложение ещё не подключено к серверу (NIIConfig)."
        case .http(let code, let message): return message.isEmpty ? "Ошибка сервера (\(code))." : message
        case .confirmEmail: return "Мы отправили письмо. Подтвердите email по ссылке и войдите."
        case .noSession: return "Войдите в аккаунт."
        }
    }

    /// Supabase / PostgREST messages → understandable Russian
    static func translate(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("invalid login credentials") { return "Неверный email или пароль." }
        if lower.contains("already registered") || lower.contains("already been registered") { return "Этот email уже зарегистрирован. Войдите." }
        if lower.contains("email not confirmed") { return "Подтвердите email по ссылке из письма." }
        if lower.contains("password should be") || lower.contains("weak password") { return "Пароль слишком простой: минимум 6 символов." }
        if lower.contains("unable to validate email") || lower.contains("invalid format") { return "Неправильный email." }
        if lower.contains("row-level security") { return "Недостаточно прав для этого действия." }
        if lower.contains("duplicate key") { return "Уже сделано ранее." }
        if lower.contains("could not find the table") || lower.contains("schema cache") || lower.contains("does not exist") {
            return "В базе ещё нет таблиц НИИ. Запустите файл backend/schema.sql в Supabase → SQL Editor. (\(message))"
        }
        if lower.contains("jwt expired") { return "Сессия устарела, войдите снова." }
        return message
    }
}

/// Persists the login between launches (Keychain on iPhone).
enum SessionStore {
    private static let account = "nii.session"

    static func load() -> AuthSession? {
        guard let data = Keychain.read(account) else { return nil }
        return try? JSONDecoder.nii.decode(AuthSession.self, from: data)
    }

    static func save(_ session: AuthSession?) {
        if let session, let data = try? JSONEncoder.nii.encode(session) {
            Keychain.write(data, account)
        } else {
            Keychain.delete(account)
        }
    }
}

@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient(url: NIIConfig.supabaseURL, key: NIIConfig.supabaseKey)

    private let baseURL: String
    private let key: String
    private let urlSession: URLSession

    private(set) var session: AuthSession? {
        didSet { if persist { SessionStore.save(session) } }
    }
    private let persist: Bool

    init(url: String, key: String, persist: Bool = true, urlSession: URLSession = .shared) {
        var base = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        self.baseURL = base
        self.key = key
        self.persist = persist
        self.urlSession = urlSession
        self.session = persist ? SessionStore.load() : nil
    }

    var userID: UUID? { session?.userID }

    // MARK: - HTTP

    private func send(_ path: String, method: String = "GET", body: Data? = nil,
                      authorized: Bool = true, headers: [String: String] = [:]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw NIIError.notConfigured }
        if authorized { try await refreshIfNeeded() }

        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "apikey")
        if authorized, let token = session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(code) else {
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = (object?["msg"] ?? object?["message"] ?? object?["error_description"] ?? object?["error"]) as? String ?? ""
            if code == 401, authorized, message.lowercased().contains("jwt") { session = nil }
            throw NIIError.http(code, NIIError.translate(message))
        }
        return data
    }

    // MARK: - Auth

    private func applyAuth(_ data: Data, fallbackEmail: String) -> AuthSession? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any],
              let idText = user["id"] as? String, let id = UUID(uuidString: idText) else { return nil }
        let expiresIn = object["expires_in"] as? Double ?? 3600
        return AuthSession(accessToken: access, refreshToken: refresh, userID: id,
                           email: user["email"] as? String ?? fallbackEmail,
                           expiresAt: Date().addingTimeInterval(expiresIn - 60))
    }

    /// Returns true when the user is signed in right away (email confirmation is off).
    func signUp(email: String, password: String, fullName: String) async throws -> Bool {
        let body = try JSONSerialization.data(withJSONObject: [
            "email": email, "password": password, "data": ["full_name": fullName],
        ])
        let data = try await send("/auth/v1/signup", method: "POST", body: body, authorized: false)
        if let new = applyAuth(data, fallbackEmail: email) {
            session = new
            return true
        }
        return false
    }

    func signIn(email: String, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await send("/auth/v1/token?grant_type=password", method: "POST", body: body, authorized: false)
        guard let new = applyAuth(data, fallbackEmail: email) else { throw NIIError.http(0, "Не удалось войти.") }
        session = new
    }

    func resetPassword(email: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email])
        _ = try await send("/auth/v1/recover", method: "POST", body: body, authorized: false)
    }

    func signOut() async {
        if session != nil {
            _ = try? await send("/auth/v1/logout", method: "POST", body: Data("{}".utf8))
        }
        session = nil
    }

    func refreshIfNeeded() async throws {
        guard let current = session else { return }
        guard current.expiresAt < Date() else { return }
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": current.refreshToken])
        do {
            let data = try await send("/auth/v1/token?grant_type=refresh_token", method: "POST", body: body, authorized: false)
            session = applyAuth(data, fallbackEmail: current.email)
        } catch {
            session = nil
            throw NIIError.noSession
        }
    }

    // MARK: - Database (PostgREST)

    /// select("nii_events", "select=*&order=starts_at")
    func select<T: Decodable>(_ table: String, _ query: String = "select=*") async throws -> [T] {
        let data = try await send("/rest/v1/\(table)?\(query)")
        return try JSONDecoder.nii.decode([T].self, from: data)
    }

    @discardableResult
    func insert<T: Encodable>(_ table: String, _ value: T) async throws -> Data {
        try await send("/rest/v1/\(table)", method: "POST", body: JSONEncoder.nii.encode(value),
                       headers: ["Prefer": "return=representation"])
    }

    func insertReturning<T: Encodable, R: Decodable>(_ table: String, _ value: T) async throws -> R {
        let data = try await insert(table, value)
        guard let first = try JSONDecoder.nii.decode([R].self, from: data).first else {
            throw NIIError.http(0, NIIError.translate("row-level security"))
        }
        return first
    }

    /// update("nii_tasks", "id=eq.5", ["status": "done", "done_at": NSNull()])
    func update(_ table: String, _ match: String, _ fields: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: fields)
        let data = try await send("/rest/v1/\(table)?\(match)", method: "PATCH", body: body,
                                  headers: ["Prefer": "return=representation"])
        // PostgREST answers [] when RLS silently filtered the row out
        if let rows = try? JSONSerialization.jsonObject(with: data) as? [Any], rows.isEmpty {
            throw NIIError.http(403, NIIError.translate("row-level security"))
        }
    }

    func delete(_ table: String, _ match: String) async throws {
        _ = try await send("/rest/v1/\(table)?\(match)", method: "DELETE")
    }

    func rpc<R: Decodable>(_ function: String, _ params: [String: Any] = [:]) async throws -> R {
        let data = try await send("/rest/v1/rpc/\(function)", method: "POST",
                                  body: try JSONSerialization.data(withJSONObject: params))
        return try JSONDecoder.nii.decode(R.self, from: data)
    }
}

extension String {
    /// Value for a PostgREST filter: "eq." + encoded value
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? self
    }
}
