//
//  SupabaseAuth.swift
//  Engineering Notebook
//
//  Email/password authentication against Supabase Auth (GoTrue), with the
//  session persisted to the Keychain and automatic access-token refresh.
//

import Foundation
import Security

/// A signed-in user's tokens, persisted to the Keychain across launches.
struct SupabaseSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userEmail: String?
}

enum AuthError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .invalidResponse:
            return "The authentication server returned an unexpected response."
        }
    }
}

@MainActor
@Observable
final class SupabaseAuthClient {
    private let projectURL: URL
    private let anonKey: String
    private let urlSession: URLSession = .shared
    private static let keychainKey = "supabase-session"

    /// The current session, or `nil` when signed out. Drives the auth UI.
    private(set) var session: SupabaseSession?

    /// Deduplicates concurrent token refreshes so parallel API calls don't
    /// both try to redeem the same refresh token.
    @ObservationIgnored private var refreshTask: Task<SupabaseSession, Error>?

    init(projectURL: URL, anonKey: String) {
        self.projectURL = projectURL
        self.anonKey = anonKey
        if let data = KeychainStore.load(key: Self.keychainKey),
           let saved = try? JSONDecoder().decode(SupabaseSession.self, from: data) {
            session = saved
        }
    }

    // MARK: Sign up / in / out

    /// Creates an account. Returns `true` if the user is immediately signed in,
    /// or `false` if Supabase sent a confirmation email that must be tapped first.
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await authRequest(
            path: "signup",
            body: ["email": email, "password": password]
        )
        guard let session = makeSession(from: response, fallbackEmail: email) else {
            // No tokens back means "Confirm email" is enabled for the project.
            return false
        }
        setSession(session)
        return true
    }

    func signIn(email: String, password: String) async throws {
        let response = try await authRequest(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password]
        )
        guard let session = makeSession(from: response, fallbackEmail: email) else {
            throw AuthError.invalidResponse
        }
        setSession(session)
    }

    func signOut() async {
        // Best-effort server-side revocation; always clear locally.
        if let token = session?.accessToken {
            var request = URLRequest(url: projectURL.appending(path: "auth/v1/logout"))
            request.httpMethod = "POST"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await urlSession.data(for: request)
        }
        clearSession()
    }

    // MARK: Token access

    /// Returns a currently valid access token, refreshing it first if it's
    /// about to expire. Returns `nil` when signed out.
    func validAccessToken() async throws -> String? {
        guard let current = session else { return nil }
        if current.expiresAt > Date.now.addingTimeInterval(60) {
            return current.accessToken
        }

        if let refreshTask {
            return try await refreshTask.value.accessToken
        }

        let task = Task<SupabaseSession, Error> { [refreshToken = current.refreshToken] in
            let response = try await self.authRequest(
                path: "token",
                query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                body: ["refresh_token": refreshToken]
            )
            guard let refreshed = self.makeSession(from: response, fallbackEmail: current.userEmail) else {
                throw AuthError.invalidResponse
            }
            return refreshed
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let refreshed = try await task.value
            setSession(refreshed)
            return refreshed.accessToken
        } catch let error as AuthError {
            // The server rejected the refresh token — this session is dead.
            clearSession()
            throw error
        }
    }

    // MARK: Requests

    private struct AuthResponse: Codable {
        var accessToken: String?
        var refreshToken: String?
        var expiresIn: Double?
        var user: AuthUser?

        struct AuthUser: Codable {
            var email: String?
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    private struct AuthErrorBody: Codable {
        var msg: String?
        var errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case msg
            case errorDescription = "error_description"
        }
    }

    private func authRequest(
        path: String,
        query: [URLQueryItem] = [],
        body: [String: String]
    ) async throws -> AuthResponse {
        let url = projectURL.appending(path: "auth/v1/\(path)")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let finalURL = components.url else { throw AuthError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = (try? JSONDecoder().decode(AuthErrorBody.self, from: data))
                .flatMap { $0.msg ?? $0.errorDescription }
            throw AuthError.server(serverMessage ?? "Sign-in failed (HTTP \(http.statusCode)).")
        }
        do {
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        } catch {
            throw AuthError.invalidResponse
        }
    }

    // MARK: Session state

    private func makeSession(from response: AuthResponse, fallbackEmail: String?) -> SupabaseSession? {
        guard let access = response.accessToken, let refresh = response.refreshToken else {
            return nil
        }
        return SupabaseSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date.now.addingTimeInterval(response.expiresIn ?? 3600),
            userEmail: response.user?.email ?? fallbackEmail
        )
    }

    private func setSession(_ newSession: SupabaseSession) {
        session = newSession
        if let data = try? JSONEncoder().encode(newSession) {
            KeychainStore.save(data, key: Self.keychainKey)
        }
    }

    private func clearSession() {
        session = nil
        KeychainStore.delete(key: Self.keychainKey)
    }
}

// MARK: - Keychain

/// Minimal generic-password Keychain wrapper for storing the auth session.
enum KeychainStore {
    private static func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EngineeringNotebook",
            kSecAttrAccount as String: key,
        ]
    }

    static func save(_ data: Data, key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
        var attributes = baseQuery(key: key)
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
    }
}
