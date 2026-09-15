//
//  ProjectDetailView.swift
//  Engineering Notebook
//
//  Lists the entries for a project and lets the user add a new observation.
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project

    @Environment(NotebookStore.self) private var store
    @State private var isPresentingNewEntry = false

    private var entries: [Entry] {
        store.entries(for: project.id)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No Observations", systemImage: "note.text")
                } description: {
                    Text("Add a note, photo, location, and measurements from the field.")
                } actions: {
                    Button("Add Observation") { isPresentingNewEntry = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                entryList
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewEntry = true
                } label: {
                    Label("Add Observation", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewEntry) {
            EntryEditorView(projectID: project.id)
        }
        .task {
            await store.loadEntries(projectID: project.id)
        }
        .refreshable {
            await store.loadEntries(projectID: project.id)
        }
    }

    private var entryList: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry)
                }
            }
            .onDelete { offsets in
                let toDelete = offsets.map { entries[$0] }
                Task { await store.deleteEntries(toDelete, from: project.id) }
            }
        }
        .navigationDestination(for: Entry.self) { entry in
            EntryDetailView(entry: entry)
        }
    }
}

/// A single row summarizing an entry in the list.
private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            if let data = entry.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.note.isEmpty ? "Observation" : entry.note)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                    if entry.location != nil {
                        Label("Located", systemImage: "location.fill")
                            .labelStyle(.iconOnly)
                    }
                    if let rating = entry.rating {
                        RatingLabel(rating: rating)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
