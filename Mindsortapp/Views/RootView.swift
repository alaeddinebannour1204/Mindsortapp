//
//  RootView.swift
//  Mindsortapp
//
//  Root: shows Auth when unauthenticated, Home when authenticated.
//

import SwiftData
import SwiftUI
import Supabase

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var authService: AuthService?
    @State private var apiService: APIService?
    @State private var syncService: SyncService?
    @State private var checkedSession = false

    var body: some View {
        Group {
            if !checkedSession {
                ProgressView(store.t("common.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
            } else if let userId = store.userId, !userId.isEmpty {
                HomeView()
            } else if let auth = authService {
                AuthView(authService: auth)
            } else {
                AuthConfigErrorView(store: store)
            }
        }
        .environment(\.authService, authService)
        .environment(\.apiService, apiService)
        .environment(\.syncService, syncService)
        .task {
            await setupAuthAndSession()
        }
    }

    private func setupAuthAndSession() async {
        guard let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else {
            authService = nil
            apiService = nil
            syncService = nil
            checkedSession = true
            return
        }
        let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        authService = AuthService(client: client)
        let api = APIService(client: client)
        apiService = api
        syncService = SyncService(modelContext: modelContext, api: api, store: store)
        if let uid = await authService?.currentUserId() {
            store.hydrate(userId: uid)
        }
        checkedSession = true
    }
}

/// Shown when Supabase URL/key are not configured
private struct AuthConfigErrorView: View {
    let store: AppStore

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(store.t("config.notConfigured"))
                .font(Theme.Typography.h2())
            Text(store.t("config.instructions"))
                .font(Theme.Typography.bodySmall())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

#Preview {
    RootView()
        .environment(AppStore())
}
