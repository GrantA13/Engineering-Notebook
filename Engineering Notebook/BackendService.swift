//
//  BackendService.swift
//  Engineering Notebook
//
//  Abstraction over the remote database. The app talks to this protocol so the
//  real REST client and the local mock stub are interchangeable.
//

import Foundation

/// The set of operations the app needs from its backend database.
///
/// Both `RESTBackendService` (talks to a real HTTP API) and
/// `MockBackendService` (an in-process, disk-backed stub) conform to this, so
/// the rest of the app never needs to know which one is in use.
protocol BackendService: Sendable {
    func fetchProjects() async throws -> [Project]
    func createProject(_ project: Project) async throws -> Project
    func deleteProject(id: UUID) async throws

    func fetchEntries(projectID: UUID) async throws -> [Entry]
    func createEntry(_ entry: Entry) async throws -> Entry
    func deleteEntry(id: UUID) async throws
}

/// Errors surfaced by backend implementations.
enum BackendError: LocalizedError {
    case invalidResponse
    case http(status: Int)
    case decoding(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .http(let status):
            return "The server responded with an error (HTTP \(status))."
        case .decoding(let detail):
            return "Could not read the server's response: \(detail)"
        case .notFound:
            return "The requested item could not be found."
        }
    }
}

/// Central place to configure which backend the app uses.
///
/// Priority order: Supabase (if both values below are filled in), then a
/// custom REST server (if `backendBaseURL` is set), then the on-device mock.
enum AppConfiguration {
    // MARK: Supabase
    /// Your Supabase project URL, from Project Settings → Data API,
    /// e.g. `URL(string: "https://abcdefgh.supabase.co")`.
    static let supabaseProjectURL: URL? = URL(string: "https://vsucwzfbtvijymsqwfzo.supabase.co")
    /// Your Supabase anon (public) API key, from Project Settings → API Keys.
    static let supabaseAnonKey = "sb_publishable_tI_3CNFG3vJ6SiabiFQKFQ_opmUikgC"

    // MARK: Custom REST server
    /// when running the bundled `MockServer`) to use the generic REST client.
    static let backendBaseURL: URL? = nil

    /// Builds the auth client when Supabase is configured; `nil` otherwise
    /// (the mock and generic REST backends don't use authentication).
    static func makeSupabaseAuthClient() -> SupabaseAuthClient? {
        guard let projectURL = supabaseProjectURL, !supabaseAnonKey.isEmpty else {
            return nil
        }
        return SupabaseAuthClient(projectURL: projectURL, anonKey: supabaseAnonKey)
    }

    /// Builds the backend service the app should use, based on the config above.
    static func makeBackendService(auth: SupabaseAuthClient? = nil) -> BackendService {
        if let projectURL = supabaseProjectURL, !supabaseAnonKey.isEmpty {
            return SupabaseBackendService(projectURL: projectURL, anonKey: supabaseAnonKey, auth: auth)
        } else if let baseURL = backendBaseURL {
            return RESTBackendService(baseURL: baseURL)
        } else {
            return MockBackendService()
        }
    }
}

/// JSON coders configured for the API contract (ISO-8601 dates).
///
/// These are `nonisolated` computed properties that hand back a fresh coder on
/// each access, so they're safe to use from any actor (e.g. `MockBackendService`)
/// without sharing mutable state across concurrency domains.
enum APICoders {
    nonisolated static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    nonisolated static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
