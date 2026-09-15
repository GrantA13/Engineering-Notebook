//
//  ContentView.swift
//  Engineering Notebook
//
//  Created by Grant Andrews on 9/9/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(NotebookStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ProjectListView()
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                ),
                presenting: store.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: { message in
                Text(message)
            }
    }
}

#Preview {
    ContentView()
        .environment(NotebookStore(service: MockBackendService()))
}
