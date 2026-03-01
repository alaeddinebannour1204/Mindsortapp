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
            Section(store.t("settings.account")) {
                LabeledContent(store.t("settings.userId"), value: store.userId ?? store.t("settings.unknown"))
            }

            Section(store.t("settings.preferences")) {
                Picker(store.t("settings.appLanguage"), selection: $store.appLanguage) {
                    ForEach(L.appLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }

                Picker(store.t("settings.recordingLanguage"), selection: $store.defaultThoughtLanguage) {
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
                        Text(store.t("settings.signOut"))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(store.t("common.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(store.t("settings.signOutConfirm"), isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button(store.t("settings.signOut"), role: .destructive) {
                signOut()
            }
        } message: {
            Text(store.t("settings.signOutMessage"))
        }
        .alert(store.t("common.error"), isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(store.t("common.ok"), role: .cancel) {}
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
