//
//  HomeView.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @State private var showCreateCategory = false
    @State private var showRecordSheet = false
    @State private var newCategoryName = ""
    @Query private var categoryModels: [CategoryModel]

    private var db: DatabaseService { DatabaseService(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("MindSort")
                        .font(Theme.Typography.h1())
                        .foregroundStyle(Theme.Colors.text)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.lg)

                    LazyVStack(spacing: Theme.Spacing.md) {
                        NavigationLink {
                            SearchView()
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Theme.Colors.textTertiary)
                                Text("Search thoughts...")
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Colors.border, lineWidth: 1)
                            )
                        }

                        if store.inboxCount > 0 {
                            NavigationLink {
                                CategoryDetailView(categoryId: "__inbox__")
                            } label: {
                                InboxCard(count: store.inboxCount)
                            }
                        }

                        ForEach(categoryModels.filter { $0.userID == store.userId ?? "" }) { cat in
                            NavigationLink {
                                CategoryDetailView(categoryId: cat.id)
                            } label: {
                                CategoryCard(
                                    category: cat,
                                    showNewBadge: hasNewBadge(categoryID: cat.id),
                                    isSelected: false
                                )
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                }
            }
            .background(Theme.Colors.background)
            .refreshable {
                await refresh()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            newCategoryName = ""
                            showCreateCategory = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        NavigationLink {
                            ProfilePlaceholderView()
                        } label: {
                            Image(systemName: "person.circle")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                RecordButton(isRecording: false) {
                    showRecordSheet = true
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .sheet(isPresented: $showRecordSheet) {
                RecordView(categoryId: nil)
            }
            .sheet(isPresented: $showCreateCategory) {
                createCategorySheet
            }
        }
        .navigationTitle("MindSort")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Fire sync in its own Task so it is not cancelled if the view
            // disappears (e.g. navigation push while sync is still running).
            if let uid = store.userId {
                syncService?.requestSync(userID: uid)
            }
            await loadData()
        }
    }

    private var createCategorySheet: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $newCategoryName)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateCategory = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNewCategory()
                        showCreateCategory = false
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func loadData() async {
        guard let uid = store.userId else { return }
        do {
            let count = try db.inboxCount(userID: uid)
            store.refreshInboxCount(count)
        } catch {}
    }

    private func refresh() async {
        guard let uid = store.userId else { return }
        if let sync = syncService {
            await sync.syncAll(userID: uid)
        }
        await loadData()
    }

    private func saveNewCategory() {
        guard let uid = store.userId else { return }
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            _ = try db.createCategory(userID: uid, name: name)
            syncService?.requestSync(userID: uid)
            Task { await loadData() }
        } catch {
            // Handle error
        }
    }

    private func hasNewBadge(categoryID: String) -> Bool {
        guard let uid = store.userId else { return false }
        guard let lastSeen = try? db.lastSeenDate(categoryID: categoryID, userID: uid),
              let cat = categoryModels.first(where: { $0.id == categoryID }) else {
            return false
        }
        return cat.lastUpdated > lastSeen
    }

}

// MARK: - Inbox Card

private struct InboxCard: View {
    let count: Int

    var body: some View {
            HStack {
                Image(systemName: "tray.full")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Inbox")
                        .font(Theme.Typography.h3())
                        .foregroundStyle(Theme.Colors.text)
                    Text("\(count) uncategorized")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Colors.textTertiary)
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

// MARK: - Placeholders (Phase 2+)

private struct ProfilePlaceholderView: View {
    var body: some View {
        Text("Profile")
            .font(Theme.Typography.h1())
    }
}

