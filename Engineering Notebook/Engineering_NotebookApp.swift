//
//  Engineering_NotebookApp.swift
//  Engineering Notebook
//
//  Created by Grant Andrews on 9/9/26.
//

import SwiftUI

@main
struct Engineering_NotebookApp: App {
    /// The app's data layer, backed by either the REST client or the mock,
    /// depending on `AppConfiguration.backendBaseURL`.
    @State private var store = NotebookStore(service: AppConfiguration.makeBackendService())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
