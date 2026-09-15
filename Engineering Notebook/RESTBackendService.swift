//
//  RESTBackendService.swift
//  Engineering Notebook
//
//  Talks to a remote HTTP/JSON API. See MockServer/README.md for the contract.
//

import Foundation

/// A `BackendService` backed by a remote REST API.
///
/// Endpoints:
/// - `GET    /projects`
/// - `POST   /projects`
/// - `DELETE /projects/{id}`
/// - `GET    /projects/{id}/entries`
/// - `POST   /projects/{id}/entries`
/// - `DELETE /entries/{id}`
struct RESTBackendService: BackendService {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: Projects

    func fetchProjects() async throws -> [Project] {
        try await request(path: "projects", method: "GET")
    }

    func createProject(_ project: Project) async throws -> Project {
        try await request(path: "projects", method: "POST", body: project)
    }

    func deleteProject(id: UUID) async throws {
        try await requestVoid(path: "projects/\(id.uuidString)", method: "DELETE")
    }

    // MARK: Entries

    func fetchEntries(projectID: UUID) async throws -> [Entry] {
        try await request(path: "projects/\(projectID.uuidString)/entries", method: "GET")
    }

    func createEntry(_ entry: Entry) async throws -> Entry {
        try await request(
            path: "projects/\(entry.projectID.uuidString)/entries",
            method: "POST",
            body: entry
        )
    }

    func deleteEntry(id: UUID) async throws {
        try await requestVoid(path: "entries/\(id.uuidString)", method: "DELETE")
    }

    // MARK: Request helpers

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try APICoders.encoder.encode(body)
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 { throw BackendError.notFound }
            throw BackendError.http(status: http.statusCode)
        }
    }

    /// Performs a request that returns a decodable body.
    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: (some Encodable)? = Optional<Int>.none
    ) async throws -> Response {
        let request = try makeRequest(path: path, method: method, body: body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try APICoders.decoder.decode(Response.self, from: data)
        } catch {
            throw BackendError.decoding(error.localizedDescription)
        }
    }

    /// Performs a request that returns no meaningful body.
    private func requestVoid(path: String, method: String) async throws {
        let request = try makeRequest(path: path, method: method, body: Optional<Int>.none)
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }
}
