//
//  SearchView.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiService) private var apiService

    @State private var query: String = ""
    @State private var isLoading: Bool = false
    @State private var remoteResults: [Entry] = []
    @State private var localResults: [EntryModel] = []
    @State private var usedFallback: Bool = false
    @State private var errorMessage: String?

    private var db: DatabaseService { DatabaseService(modelContext: modelContext) }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SearchBar(text: $query, placeholder: "Search thoughts...") {
                Task { await performSearch() }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if remoteResults.isEmpty && localResults.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Search by meaning")
                        .font(Theme.Typography.h2())
                    Text("Type a few words or a short sentence, then tap search.")
                        .font(Theme.Typography.bodySmall())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        if !remoteResults.isEmpty {
                            ForEach(remoteResults, id: \.id) { entry in
                                SearchResultRow(
                                    title: entry.title ?? "Untitled",
                                    transcript: entry.transcript,
                                    categoryName: entry.categoryName
                                )
                            }
                        } else {
                            ForEach(localResults) { entry in
                                SearchResultRow(
                                    title: entry.title ?? "Untitled",
                                    transcript: entry.transcript,
                                    categoryName: nil
                                )
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = store.userId else { return }

        isLoading = true
        errorMessage = nil
        usedFallback = false
        remoteResults = []
        localResults = []

        if let api = apiService {
            do {
                let entries = try await api.searchEntries(query: trimmed)
                await MainActor.run {
                    remoteResults = entries
                    isLoading = false
                }
                return
            } catch {
                usedFallback = true
            }
        }

        do {
            let local = try db.searchLocalEntries(userID: uid, query: trimmed)
            await MainActor.run {
                localResults = local
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

private struct SearchResultRow: View {
    let title: String
    let transcript: String
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(Theme.Typography.h3())
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)
                Spacer()
                if let name = categoryName, !name.isEmpty {
                    Text(name)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Text(transcript)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(3)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

