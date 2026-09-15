//
//  AuthView.swift
//  Engineering Notebook
//
//  Email/password sign-in and account creation, shown when Supabase is
//  configured and no user is signed in.
//

import SwiftUI

struct AuthView: View {
    let client: SupabaseAuthClient

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Create Account"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                } footer: {
                    if mode == .signUp {
                        Text("Password must be at least 6 characters.")
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(mode.rawValue)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isWorking || !isFormValid)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                if let infoMessage {
                    Section {
                        Text(infoMessage)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Engineering Notebook")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var isFormValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                switch mode {
                case .signIn:
                    try await client.signIn(email: email, password: password)
                case .signUp:
                    let signedIn = try await client.signUp(email: email, password: password)
                    if !signedIn {
                        infoMessage = "Check your email for a confirmation link, then come back and sign in."
                        mode = .signIn
                    }
                }
                // On success the root view switches to the main app automatically,
                // because it observes `client.session`.
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthView(client: SupabaseAuthClient(
        projectURL: URL(string: "https://example.supabase.co")!,
        anonKey: "preview"
    ))
}
