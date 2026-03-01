//
//  SettingsView.swift
//  Mindsortapp
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.authService) private var authService
    @State private var showSignOutConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Account") {
                LabeledContent("User ID", value: store.userId ?? "Unknown")
            }

            Section("Preferences") {
                Picker("Recording language", selection: $store.defaultThoughtLanguage) {
                    ForEach(TranscriptionService.supportedLocales, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Your data is saved on the server. You can sign back in anytime.")
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    private func signOut() {
        Task {
            do {
                try await authService?.signOut()
                store.userId = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
