//
//  ContentView.swift
//  Engineering Notebook
//
//  Created by Grant Andrews on 9/9/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(NotebookStore.self) private var store
    /// Non-nil when the app is using the Supabase backend; gates the main UI
    /// behind sign-in.
    let auth: SupabaseAuthClient?

    var body: some View {
        @Bindable var store = store
        Group {
            if let auth, auth.session == nil {
                AuthView(client: auth)
            } else {
                ProjectListView()
            }
        }
        .environment(auth)
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
    ContentView(auth: nil)
        .environment(NotebookStore(service: MockBackendService()))
}
