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
enum AppConfiguration {
    /// Set this to your deployed API's base URL (e.g. `http://localhost:3000`
    /// when running the bundled `MockServer`) to use the real REST client.
    ///
    /// While `nil`, the app uses the on-device `MockBackendService` so it runs
    /// fully offline with no server required.
    static let backendBaseURL: URL? = nil

    /// Builds the backend service the app should use, based on the config above.
    static func makeBackendService() -> BackendService {
        if let baseURL = backendBaseURL {
            return RESTBackendService(baseURL: baseURL)
        } else {
            return MockBackendService()
        }
    }
}

/// Shared JSON coders configured for the API contract (ISO-8601 dates).
enum APICoders {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
