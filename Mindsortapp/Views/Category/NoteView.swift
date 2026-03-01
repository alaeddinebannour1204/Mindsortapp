//
//  NoteView.swift
//  Mindsortapp
//
//  Full-screen note editor for a category. The category IS the note.
//  Pending entries appear at the top for review (keep or reassign).
//  The merged note body is one continuous rich text surface below.
//

import SwiftUI
import SwiftData

struct NoteView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService

    let categoryId: String

    @State private var category: CategoryModel?
    @State private var pendingEntries: [EntryModel] = []
    @State private var allCategories: [CategoryModel] = []
    @State private var isLoading = true
    @State private var showRecordSheet = false
    @State private var movingEntry: EntryModel?
    @State private var errorMessage: String?
    @State private var undoMessage: String?
    @State private var undoAction: (() -> Void)?
    @State private var undoTimer: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?

    // Rich text state
    @State private var attributedText = NSAttributedString()
    @State private var plainText = ""

    // Editable title
    @State private var editableTitle = ""

    private var db: DatabaseService { DatabaseService(modelContext: modelContext) }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
            } else {
                noteContent
            }
        }
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showRecordSheet = true
                    } label: {
                        Label("Record thought", systemImage: "mic.fill")
                    }
                    Button {
                        addTextBlock()
                    } label: {
                        Label("Add text", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showRecordSheet = true
            } label: {
                RecordButton(isRecording: false) {}
            }
            .padding(.bottom, Theme.Spacing.xl)
            .padding(.trailing, Theme.Spacing.lg)
        }
        .overlay(alignment: .bottom) {
            if let msg = undoMessage {
                UndoToast(message: msg) {
                    undoAction?()
                    clearUndo()
                }
            }
        }
        .animation(.spring(response: 0.35), value: undoMessage)
        .sheet(isPresented: $showRecordSheet) {
            RecordView(categoryId: categoryId)
        }
        .sheet(item: $movingEntry) { entry in
            CategoryPickerSheet(
                currentCategoryId: categoryId,
                categories: allCategories,
                onSelect: { targetCategory in
                    moveEntry(entry, to: targetCategory)
                },
                onCreateNew: { name in
                    createCategoryAndMove(entry: entry, categoryName: name)
                }
            )
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .task {
            await load()
        }
        .onChange(of: showRecordSheet) { _, isShowing in
            if !isShowing {
                // Reload when record sheet dismisses to pick up new entries
                Task { await load() }
            }
        }
    }

    // MARK: - Note Content

    private var noteContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Editable title
                titleField

                // Pending entries zone
                if !pendingEntries.isEmpty {
                    pendingSection
                }

                // Separator between pending and note body
                if !pendingEntries.isEmpty && !plainText.isEmpty {
                    separator
                }

                // The giant rich text note body
                noteBody

                // Bottom padding so content isn't hidden behind FAB
                Spacer()
                    .frame(height: 120)
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var titleField: some View {
        TextField("Note title", text: $editableTitle)
            .font(Font(UIFont.systemFont(ofSize: 28, weight: .bold)))
            .foregroundStyle(Theme.Colors.text)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            .onChange(of: editableTitle) { _, _ in
                scheduleTitleSave()
            }
            .accessibilityLabel("Note title")
    }

    private var pendingSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(pendingEntries) { entry in
                PendingEntryBlock(
                    entry: entry,
                    onKeep: { mergeEntry(entry) },
                    onMove: { movingEntry = entry }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .padding(.bottom, Theme.Spacing.md)
        .animation(.spring(response: 0.4), value: pendingEntries.map(\.id))
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 1)
            .padding(.vertical, Theme.Spacing.md)
    }

    private var noteBody: some View {
        RichTextEditor(
            attributedText: $attributedText,
            plainText: $plainText,
            placeholder: pendingEntries.isEmpty ? "Start writing…" : ""
        )
        .frame(minHeight: 200)
        .onChange(of: plainText) { _, _ in
            scheduleNoteSave()
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let uid = store.userId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Load category
            category = try db.fetchCategory(by: categoryId)
            editableTitle = category?.name ?? ""

            // Load all categories for the Move picker
            allCategories = try db.fetchAllCategories(userID: uid)

            // One-time migration: merge existing entries into note body
            try db.migrateEntriesToNoteBody(categoryID: categoryId, userID: uid)
            // Reload category after migration
            category = try db.fetchCategory(by: categoryId)

            // Auto-merge: entries that were seen before but not acted on
            try autoMergeSeenEntries(userID: uid)

            // Load remaining pending entries
            let allEntries = try db.fetchPendingEntries(categoryID: categoryId, userID: uid)
            pendingEntries = allEntries

            // Mark pending entries as seen
            for entry in pendingEntries where entry.seenAt == nil {
                entry.seenAt = Date()
            }
            try modelContext.save()

            // Load rich text content
            if let richData = category?.richNoteBody,
               let archived = RichTextArchiver.unarchive(richData) {
                attributedText = archived
                plainText = archived.string
            } else {
                let body = category?.noteBody ?? ""
                plainText = body
                attributedText = RichTextArchiver.fromPlainText(body)
            }

            // Clear the "NEW" badge
            store.newlySortedCategoryIDs.remove(categoryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Auto-merge on open

    private func autoMergeSeenEntries(userID: String) throws {
        let seenPending = try db.fetchSeenPendingEntries(categoryID: categoryId, userID: userID)
        guard !seenPending.isEmpty, let cat = category else { return }

        // Sort oldest first so newest ends up at top after sequential prepend
        let sorted = seenPending.sorted { $0.createdAt < $1.createdAt }
        for entry in sorted {
            let text = entry.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                if cat.noteBody.isEmpty {
                    cat.noteBody = text
                } else {
                    cat.noteBody = text + "\n\n" + cat.noteBody
                }
                // Also update rich text
                if let richData = cat.richNoteBody,
                   let existing = RichTextArchiver.unarchive(richData) {
                    let newPart = RichTextArchiver.fromPlainText(text + "\n\n")
                    let combined = NSMutableAttributedString(attributedString: newPart)
                    combined.append(existing)
                    cat.richNoteBody = RichTextArchiver.archive(combined)
                }
            }
            entry.isPending = false
            entry.syncStatus = .pendingDelete
        }
        cat.lastUpdated = Date()
        cat.syncStatus = .pendingUpdate
        try modelContext.save()
        syncService?.requestSync(userID: userID)
    }

    // MARK: - Merge a single entry (user tapped "Keep")

    private func mergeEntry(_ entry: EntryModel) {
        guard let cat = category, let uid = store.userId else { return }
        let text = entry.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prepend to note body (newest at top)
        if !text.isEmpty {
            let hadExistingContent = !cat.noteBody.isEmpty
            if hadExistingContent {
                cat.noteBody = text + "\n\n" + cat.noteBody
            } else {
                cat.noteBody = text
            }

            // Update rich text
            let separator = hadExistingContent ? "\n\n" : ""
            let newPart = RichTextArchiver.fromPlainText(text + separator)
            let combined = NSMutableAttributedString(attributedString: newPart)
            if attributedText.length > 0 {
                combined.append(attributedText)
            }
            attributedText = combined
            plainText = combined.string
            cat.richNoteBody = RichTextArchiver.archive(combined)
        }

        // Remove from pending list
        withAnimation {
            pendingEntries.removeAll { $0.id == entry.id }
        }

        // Mark entry for deletion
        entry.isPending = false
        entry.syncStatus = .pendingDelete

        cat.lastUpdated = Date()
        cat.syncStatus = .pendingUpdate

        do {
            try modelContext.save()
            syncService?.requestSync(userID: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Move entry to another category

    private func moveEntry(_ entry: EntryModel, to target: CategoryModel) {
        guard let uid = store.userId else { return }

        let previousCategoryId = entry.categoryID
        entry.categoryID = target.id
        entry.seenAt = nil // Reset so it shows as new in the target category
        entry.syncStatus = .pendingUpdate

        withAnimation {
            pendingEntries.removeAll { $0.id == entry.id }
        }

        do {
            try modelContext.save()
            syncService?.requestSync(userID: uid)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Show undo toast
        showUndo(message: "Moved to \(target.name)") {
            entry.categoryID = previousCategoryId
            entry.seenAt = Date()
            entry.syncStatus = .pendingUpdate
            do {
                try self.modelContext.save()
                self.syncService?.requestSync(userID: uid)
                withAnimation {
                    self.pendingEntries.insert(entry, at: 0)
                }
            } catch {}
        }
    }

    // MARK: - Create category and move

    private func createCategoryAndMove(entry: EntryModel, categoryName: String) {
        guard let uid = store.userId else { return }
        do {
            let newCat = try db.createCategory(userID: uid, name: categoryName)
            moveEntry(entry, to: newCat)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add empty text block (becomes part of the note body directly)

    private func addTextBlock() {
        // Just focus the rich text editor — the user types directly into the note
        // Insert a newline at the top if there's existing content
        guard let cat = category else { return }
        if !plainText.isEmpty {
            let newPart = NSAttributedString(string: "\n\n", attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
            ])
            let combined = NSMutableAttributedString(attributedString: newPart)
            combined.append(attributedText)
            attributedText = combined
            plainText = combined.string
        }
        // The text view will be focused via the keyboard
        _ = cat // Silence unused warning
    }

    // MARK: - Saving

    private func scheduleTitleSave() {
        guard let cat = category, let uid = store.userId else { return }
        let newTitle = editableTitle.trimmingCharacters(in: .whitespaces)
        guard newTitle != cat.name else { return }

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                cat.name = newTitle.isEmpty ? "Untitled" : newTitle
                cat.lastUpdated = Date()
                cat.syncStatus = .pendingUpdate
                try? modelContext.save()
                syncService?.requestSync(userID: uid)
            }
        }
    }

    private func scheduleNoteSave() {
        guard let cat = category, let uid = store.userId else { return }

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                cat.noteBody = plainText
                cat.richNoteBody = RichTextArchiver.archive(attributedText)
                cat.lastUpdated = Date()
                cat.syncStatus = .pendingUpdate
                try? modelContext.save()
                syncService?.requestSync(userID: uid)
            }
        }
    }

    // MARK: - Undo

    private func showUndo(message: String, action: @escaping () -> Void) {
        undoTimer?.cancel()
        undoMessage = message
        undoAction = action
        undoTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { clearUndo() }
        }
    }

    private func clearUndo() {
        undoTimer?.cancel()
        undoTimer = nil
        undoMessage = nil
        undoAction = nil
    }
}
