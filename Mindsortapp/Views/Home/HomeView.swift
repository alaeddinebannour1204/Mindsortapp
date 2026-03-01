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
    @State private var renamingCategory: CategoryModel?
    @State private var renameCategoryName = ""
    @State private var deletingCategory: CategoryModel?
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

                    if syncService?.syncing == true {
                        HStack(spacing: Theme.Spacing.sm) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Syncing...")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .transition(.opacity)
                    } else if syncService?.lastSyncFailed == true {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.record)
                            Text("Sync failed — pull to retry")
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .transition(.opacity)
                        .accessibilityLabel("Sync failed. Pull down to retry.")
                    }

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
                        .accessibilityLabel("Search thoughts")

                        if store.inboxCount > 0 {
                            NavigationLink {
                                CategoryDetailView(categoryId: "__inbox__")
                            } label: {
                                InboxCard(count: store.inboxCount)
                            }
                        }

                        ForEach(categoryModels.filter { $0.userID == store.userId ?? "" }) { cat in
                            NavigationLink {
                                NoteView(categoryId: cat.id)
                            } label: {
                                CategoryCard(
                                    category: cat,
                                    showNewBadge: hasNewBadge(categoryID: cat.id),
                                    isSelected: false
                                )
                            }
                            .contextMenu {
                                Button {
                                    renameCategoryName = cat.name
                                    renamingCategory = cat
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deletingCategory = cat
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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
                        .accessibilityLabel("Create category")
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "person.circle")
                        }
                        .accessibilityLabel("Settings")
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
            .alert("Rename Category", isPresented: .init(
                get: { renamingCategory != nil },
                set: { if !$0 { renamingCategory = nil } }
            )) {
                TextField("Name", text: $renameCategoryName)
                Button("Cancel", role: .cancel) { renamingCategory = nil }
                Button("Save") { renameCategory() }
            }
            .confirmationDialog(
                "Delete \"\(deletingCategory?.name ?? "")\"?",
                isPresented: .init(
                    get: { deletingCategory != nil },
                    set: { if !$0 { deletingCategory = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteCategory() }
            } message: {
                Text("This will delete the category and all its thoughts. This cannot be undone.")
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

    private func renameCategory() {
        guard let cat = renamingCategory, let uid = store.userId else { return }
        let name = renameCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try db.updateCategory(id: cat.id, name: name)
            syncService?.requestSync(userID: uid)
        } catch {}
        renamingCategory = nil
    }

    private func deleteCategory() {
        guard let cat = deletingCategory, let uid = store.userId else { return }
        do {
            try db.deleteCategory(id: cat.id)
            syncService?.requestSync(userID: uid)
            Task { await loadData() }
        } catch {}
        deletingCategory = nil
    }

    private func hasNewBadge(categoryID: String) -> Bool {
        store.newlySortedCategoryIDs.contains(categoryID)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Inbox, \(count) uncategorized thoughts")
    }
}



