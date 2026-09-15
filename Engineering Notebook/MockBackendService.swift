//
//  MockBackendService.swift
//  Engineering Notebook
//
//  An in-process stand-in for the remote database. It persists to a JSON file
//  in Application Support so entries survive relaunches, and adds a small
//  artificial delay to mimic network latency. This lets the app run and be
//  demoed with no server deployed.
//

import Foundation

/// A disk-backed, in-memory implementation of `BackendService`.
///
/// Implemented as an `actor` so its mutable store is safe to touch from any
/// task, mirroring how a real networked backend serializes access.
actor MockBackendService: BackendService {
    private var projects: [Project]
    private var entries: [Entry]

    private let storeURL: URL
    /// Simulated round-trip latency.
    private let latency: Duration

    init(latency: Duration = .milliseconds(300)) {
        self.latency = latency

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.storeURL = support.appending(path: "mock-backend.json")

        // Load any previously persisted data.
        if let data = try? Data(contentsOf: storeURL),
           let snapshot = try? APICoders.decoder.decode(Snapshot.self, from: data) {
            self.projects = snapshot.projects
            self.entries = snapshot.entries
        } else {
            self.projects = []
            self.entries = []
        }
    }

    // MARK: Projects

    func fetchProjects() async throws -> [Project] {
        try await simulateLatency()
        return projects.sorted { $0.createdAt > $1.createdAt }
    }

    func createProject(_ project: Project) async throws -> Project {
        try await simulateLatency()
        projects.append(project)
        persist()
        return project
    }

    func deleteProject(id: UUID) async throws {
        try await simulateLatency()
        projects.removeAll { $0.id == id }
        entries.removeAll { $0.projectID == id }
        persist()
    }

    // MARK: Entries

    func fetchEntries(projectID: UUID) async throws -> [Entry] {
        try await simulateLatency()
        return entries
            .filter { $0.projectID == projectID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createEntry(_ entry: Entry) async throws -> Entry {
        try await simulateLatency()
        entries.append(entry)
        persist()
        return entry
    }

    func deleteEntry(id: UUID) async throws {
        try await simulateLatency()
        entries.removeAll { $0.id == id }
        persist()
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var projects: [Project]
        var entries: [Entry]
    }

    private func persist() {
        let snapshot = Snapshot(projects: projects, entries: entries)
        if let data = try? APICoders.encoder.encode(snapshot) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    private func simulateLatency() async throws {
        try await Task.sleep(for: latency)
    }
}
