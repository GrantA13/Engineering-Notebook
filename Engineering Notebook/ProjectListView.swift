//
//  ProjectListView.swift
//  Engineering Notebook
//
//  Root screen: lists engineering projects and lets the user create new ones.
//

import SwiftUI

struct ProjectListView: View {
    @Environment(NotebookStore.self) private var store
    @State private var isPresentingNewProject = false

    var body: some View {
        NavigationStack {
            Group {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects", systemImage: "folder.badge.plus")
                    } description: {
                        Text("Create an engineering project to start recording observations.")
                    } actions: {
                        Button("New Project") { isPresentingNewProject = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewProject = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewProject) {
                NewProjectView()
            }
            .task {
                await store.loadProjects()
            }
            .refreshable {
                await store.loadProjects()
            }
        }
    }

    private var projectList: some View {
        List {
            ForEach(store.projects) { project in
                NavigationLink(value: project) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        if !project.summary.isEmpty {
                            Text(project.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Text(project.createdAt, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onDelete { offsets in
                let toDelete = offsets.map { store.projects[$0] }
                Task { await store.deleteProjects(toDelete) }
            }
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
    }
}

/// Sheet for creating a new project.
struct NewProjectView: View {
    @Environment(NotebookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var summary = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Summary (optional)", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let created = await store.addProject(
                name: name.trimmingCharacters(in: .whitespaces),
                summary: summary.trimmingCharacters(in: .whitespaces)
            )
            isSaving = false
            if created != nil { dismiss() }
        }
    }
}
