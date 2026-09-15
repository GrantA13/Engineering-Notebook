//
//  Engineering_NotebookApp.swift
//  Engineering Notebook
//
//  Created by Grant Andrews on 9/9/26.
//

import SwiftUI

@main
struct Engineering_NotebookApp: App {
    /// Auth client when Supabase is configured; `nil` for the mock/REST backends.
    @State private var auth: SupabaseAuthClient?
    /// The app's data layer, backed by whichever service `AppConfiguration` selects.
    @State private var store: NotebookStore

    init() {
        let auth = AppConfiguration.makeSupabaseAuthClient()
        _auth = State(initialValue: auth)
        _store = State(initialValue: NotebookStore(service: AppConfiguration.makeBackendService(auth: auth)))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(auth: auth)
                .environment(store)
        }
    }
}
