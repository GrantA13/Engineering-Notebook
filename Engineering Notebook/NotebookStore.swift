//
//  NotebookStore.swift
//  Engineering Notebook
//
//  The app's data layer. Wraps a `BackendService`, caches results for the UI,
//  and exposes async operations plus loading/error state.
//

import Foundation

@MainActor
@Observable
final class NotebookStore {
    private let service: BackendService

    /// All projects, most recent first.
    private(set) var projects: [Project] = []
    /// Cached entries keyed by project id.
    private(set) var entriesByProject: [UUID: [Entry]] = [:]

    var isLoading = false
    /// Set when an operation fails; drives an alert in the UI.
    var errorMessage: String?

    init(service: BackendService) {
        self.service = service
    }

    // MARK: Projects

    func loadProjects() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await service.fetchProjects()
        } catch {
            report(error)
        }
    }

    /// Creates a project and returns it on success, or `nil` on failure.
    @discardableResult
    func addProject(name: String, summary: String) async -> Project? {
        let project = Project(name: name, summary: summary)
        do {
            let created = try await service.createProject(project)
            projects.insert(created, at: 0)
            return created
        } catch {
            report(error)
            return nil
        }
    }

    func deleteProjects(_ projectsToDelete: [Project]) async {
        for project in projectsToDelete {
            do {
                try await service.deleteProject(id: project.id)
                projects.removeAll { $0.id == project.id }
                entriesByProject[project.id] = nil
            } catch {
                report(error)
            }
        }
    }

    // MARK: Entries

    func entries(for projectID: UUID) -> [Entry] {
        entriesByProject[projectID] ?? []
    }

    func loadEntries(projectID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            entriesByProject[projectID] = try await service.fetchEntries(projectID: projectID)
        } catch {
            report(error)
        }
    }

    /// Saves an entry to the backend and updates the cache. Returns `true` on success.
    func addEntry(_ entry: Entry) async -> Bool {
        do {
            let created = try await service.createEntry(entry)
            entriesByProject[entry.projectID, default: []].insert(created, at: 0)
            return true
        } catch {
            report(error)
            return false
        }
    }

    func deleteEntries(_ entriesToDelete: [Entry], from projectID: UUID) async {
        for entry in entriesToDelete {
            do {
                try await service.deleteEntry(id: entry.id)
                entriesByProject[projectID]?.removeAll { $0.id == entry.id }
            } catch {
                report(error)
            }
        }
    }

    // MARK: Helpers

    private func report(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
