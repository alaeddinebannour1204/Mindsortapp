//
//  CategoryDetailView.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService

    let categoryId: String

    @State private var entries: [EntryModel] = []
    @State private var categoryName: String = ""
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var showRecordSheet: Bool = false
    @State private var editingEntryId: String?
    @State private var errorMessage: String?
    @State private var saveTasks: [String: Task<Void, Never>] = [:]

    private var db: DatabaseService { DatabaseService(modelContext: modelContext) }

    private var isInbox: Bool { categoryId == "__inbox__" }

    private var titleText: String {
        if isInbox { return "Inbox" }
        if !categoryName.isEmpty { return categoryName }
        return "Category"
    }

    private var filteredEntries: [EntryModel] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return entries
        }
        let q = searchText.lowercased()
        return entries.filter {
            $0.transcript.lowercased().contains(q) ||
            ($0.title?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
            } else if filteredEntries.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Text("No thoughts yet")
                        .font(Theme.Typography.h2())
                    Text(isInbox ? "New recordings will appear here until they are categorized." : "Tap + or use the mic to add a new thought.")
                        .font(Theme.Typography.bodySmall())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(filteredEntries) { entry in
                            EntryCard(
                                entry: entry,
                                isEditing: editingEntryId == entry.id,
                                onChange: { title, transcript in
                                    handleChange(for: entry.id, title: title, transcript: transcript)
                                },
                                onDelete: {
                                    handleDelete(entryId: entry.id)
                                },
                                onColorTap: {
                                    // Color tagging can be added in a later phase
                                }
                            )
                            .onTapGesture {
                                toggleEditing(id: entry.id)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .background(Theme.Colors.background)
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isInbox {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createInlineEntry()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .overlay(alignment: .bottomTrailing) {
            if !isInbox {
                Button {
                    showRecordSheet = true
                } label: {
                    RecordButton(isRecording: false) {}
                }
                .padding(.bottom, Theme.Spacing.xl)
                .padding(.trailing, Theme.Spacing.lg)
            }
        }
        .sheet(isPresented: $showRecordSheet) {
            RecordView(categoryId: categoryId)
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
        .task {
            await load()
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let uid = store.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if isInbox {
                entries = try db.fetchEntries(categoryID: nil, userID: uid)
            } else {
                entries = try db.fetchEntries(categoryID: categoryId, userID: uid)
                if let cat = try db.fetchCategory(by: categoryId) {
                    categoryName = cat.name
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Editing

    private func toggleEditing(id: String) {
        if editingEntryId == id {
            editingEntryId = nil
        } else {
            editingEntryId = id
        }
    }

    private func handleChange(for id: String, title: String, transcript: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].title = title.isEmpty ? nil : title
        entries[index].transcript = transcript

        saveTasks[id]?.cancel()
        saveTasks[id] = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                saveEntry(id: id)
            }
        }
    }

    private func saveEntry(id: String) {
        guard let uid = store.userId else { return }
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        do {
            try db.updateEntry(
                id: id,
                userID: uid,
                transcript: entry.transcript,
                title: entry.title,
                categoryID: entry.categoryID,
                locale: entry.locale
            )
            syncService?.requestSync(userID: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - CRUD

    private func createInlineEntry() {
        guard let uid = store.userId else { return }
        do {
            let model = try db.createEntry(
                userID: uid,
                transcript: "",
                title: "",
                categoryID: categoryId,
                locale: store.defaultThoughtLanguage
            )
            entries.insert(model, at: 0)
            editingEntryId = model.id
            syncService?.requestSync(userID: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleDelete(entryId: String) {
        guard let uid = store.userId else { return }
        do {
            try db.deleteEntry(id: entryId)
            entries.removeAll { $0.id == entryId }
            syncService?.requestSync(userID: uid)
            // Undo toast could be added here in a later refinement
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

