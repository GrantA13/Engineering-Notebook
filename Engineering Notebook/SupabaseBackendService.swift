//
//  SupabaseBackendService.swift
//  Engineering Notebook
//
//  A BackendService backed by Supabase's auto-generated REST API (PostgREST).
//  Expects `projects` and `entries` tables — see MockServer/README.md for the
//  SQL schema to create them.
//

import Foundation

struct SupabaseBackendService: BackendService {
    /// Your Supabase project URL, e.g. `https://abcdefgh.supabase.co`.
    let projectURL: URL
    /// The project's anon (public) API key.
    let anonKey: String
    /// When set, requests are authorized with the signed-in user's access
    /// token so row-level security applies per user.
    let auth: SupabaseAuthClient?

    private let session: URLSession

    init(projectURL: URL, anonKey: String, auth: SupabaseAuthClient? = nil, session: URLSession = .shared) {
        self.projectURL = projectURL
        self.anonKey = anonKey
        self.auth = auth
        self.session = session
    }

    /// The bearer token for requests: the user's access token when signed in,
    /// otherwise the anon key.
    private func bearerToken() async throws -> String {
        if let auth, let token = try await auth.validAccessToken() {
            return token
        }
        return anonKey
    }

    // MARK: Projects

    func fetchProjects() async throws -> [Project] {
        let rows: [ProjectRow] = try await get(
            table: "projects",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc"),
            ]
        )
        return rows.map(\.model)
    }

    func createProject(_ project: Project) async throws -> Project {
        let rows: [ProjectRow] = try await post(table: "projects", body: ProjectRow(project))
        guard let created = rows.first else { throw BackendError.invalidResponse }
        return created.model
    }

    func deleteProject(id: UUID) async throws {
        // Entries are removed by the `on delete cascade` foreign key.
        try await delete(table: "projects", id: id)
    }

    // MARK: Entries

    func fetchEntries(projectID: UUID) async throws -> [Entry] {
        let rows: [EntryRow] = try await get(
            table: "entries",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "project_id", value: "eq.\(projectID.uuidString)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
            ]
        )
        return rows.map(\.model)
    }

    func createEntry(_ entry: Entry) async throws -> Entry {
        let rows: [EntryRow] = try await post(table: "entries", body: EntryRow(entry))
        guard let created = rows.first else { throw BackendError.invalidResponse }
        return created.model
    }

    func deleteEntry(id: UUID) async throws {
        try await delete(table: "entries", id: id)
    }

    // MARK: Row types (snake_case column mapping)

    private struct ProjectRow: Codable {
        var id: UUID
        var name: String
        var summary: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, summary
            case createdAt = "created_at"
        }

        init(_ project: Project) {
            id = project.id
            name = project.name
            summary = project.summary
            createdAt = project.createdAt
        }

        var model: Project {
            Project(id: id, name: name, summary: summary, createdAt: createdAt)
        }
    }

    private struct EntryRow: Codable {
        var id: UUID
        var projectID: UUID
        var note: String
        var location: GeoLocation?
        var photoData: Data?
        var temperature: Double?
        var temperatureUnit: TemperatureUnit
        var measurement: Double?
        var measurementUnit: String?
        var rating: Int?
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, note, location, temperature, measurement, rating
            case projectID = "project_id"
            case photoData = "photo_data"
            case temperatureUnit = "temperature_unit"
            case measurementUnit = "measurement_unit"
            case createdAt = "created_at"
        }

        init(_ entry: Entry) {
            id = entry.id
            projectID = entry.projectID
            note = entry.note
            location = entry.location
            photoData = entry.photoData
            temperature = entry.temperature
            temperatureUnit = entry.temperatureUnit
            measurement = entry.measurement
            measurementUnit = entry.measurementUnit
            rating = entry.rating
            createdAt = entry.createdAt
        }

        var model: Entry {
            Entry(
                id: id,
                projectID: projectID,
                note: note,
                location: location,
                photoData: photoData,
                temperature: temperature,
                temperatureUnit: temperatureUnit,
                measurement: measurement,
                measurementUnit: measurementUnit,
                rating: rating,
                createdAt: createdAt
            )
        }
    }

    // MARK: JSON coders

    /// Postgres `timestamptz` values come back as ISO-8601 *with fractional
    /// seconds* (e.g. `2026-09-13T18:00:00.123456+00:00`), which the plain
    /// `.iso8601` strategy rejects — so decode with a tolerant custom strategy.
    private nonisolated static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) { return date }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: string) { return date }
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized date format: \(string)"
            ))
        }
        return decoder
    }

    private nonisolated static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: Request plumbing

    private func makeRequest(
        table: String,
        query: [URLQueryItem],
        method: String,
        token: String,
        body: Data? = nil,
        returnRepresentation: Bool = false
    ) throws -> URLRequest {
        let url = projectURL.appending(path: "rest/v1/\(table)")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let finalURL = components.url else { throw BackendError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if returnRepresentation {
            // Ask PostgREST to echo the inserted row back in the response.
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
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

    private func get<Row: Decodable>(table: String, query: [URLQueryItem]) async throws -> [Row] {
        let request = try makeRequest(table: table, query: query, method: "GET", token: await bearerToken())
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try Self.decoder.decode([Row].self, from: data)
        } catch {
            throw BackendError.decoding(error.localizedDescription)
        }
    }

    private func post<Row: Codable>(table: String, body: Row) async throws -> [Row] {
        let request = try makeRequest(
            table: table,
            query: [],
            method: "POST",
            token: await bearerToken(),
            body: Self.encoder.encode(body),
            returnRepresentation: true
        )
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try Self.decoder.decode([Row].self, from: data)
        } catch {
            throw BackendError.decoding(error.localizedDescription)
        }
    }

    private func delete(table: String, id: UUID) async throws {
        let request = try makeRequest(
            table: table,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            method: "DELETE",
            token: await bearerToken()
        )
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }
}
