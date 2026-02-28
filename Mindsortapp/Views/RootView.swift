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
    @State private var syncCoordinator: SyncCoordinator?
    @State private var checkedSession = false

    var body: some View {
        Group {
            if !checkedSession {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
            } else if let userId = store.userId, !userId.isEmpty {
                HomeView()
            } else if let auth = authService {
                AuthView(authService: auth)
            } else {
                AuthConfigErrorView()
            }
        }
        .environment(\.apiService, apiService)
        .environment(\.syncCoordinator, syncCoordinator)
        .task {
            await setupAuthAndSession()
        }
    }

    private func setupAuthAndSession() async {
        guard let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else {
            authService = nil
            apiService = nil
            syncCoordinator = nil
            checkedSession = true
            return
        }
        let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        authService = AuthService(client: client)
        let api = APIService(client: client)
        apiService = api
        syncCoordinator = SyncCoordinator(modelContext: modelContext, api: api)
        if let uid = await authService?.currentUserId() {
            store.hydrate(userId: uid)
        }
        checkedSession = true
    }
}

/// Shown when Supabase URL/key are not configured
private struct AuthConfigErrorView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("Supabase not configured")
                .font(Theme.Typography.h2())
            Text("Set SUPABASE_URL and SUPABASE_ANON_KEY in Edit Scheme → Run → Environment Variables.")
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
