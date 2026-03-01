//
//  DatabaseService.swift
//  Mindsortapp
//

import Foundation
import SwiftData

@MainActor
final class DatabaseService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllCategories(userID: String) throws -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.userID == userID && !$0.isArchived },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCategory(by id: String) throws -> CategoryModel? {
        var descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func createCategory(userID: String, name: String) throws -> CategoryModel {
        let id = UUID().uuidString
        let model = CategoryModel(
            id: id,
            userID: userID,
            name: name,
            isUserCreated: true,
            syncStatus: .pendingCreate
        )
        modelContext.insert(model)
        try modelContext.save()
        return model
    }

    func updateCategory(id: String, name: String) throws {
        guard let model = try fetchCategory(by: id) else { return }
        model.name = name
        model.lastUpdated = Date()
        model.syncStatus = .pendingUpdate
        try modelContext.save()
    }

    func deleteCategory(id: String) throws {
        guard let model = try fetchCategory(by: id) else { return }
        model.syncStatus = .pendingDelete
        try modelContext.save()
    }

    func deleteEntry(id: String) throws {
        var descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let model = try modelContext.fetch(descriptor).first else { return }
        model.syncStatus = .pendingDelete
        try modelContext.save()
    }

    func fetchEntries(categoryID: String?, userID: String) throws -> [EntryModel] {
        if let catId = categoryID, !catId.isEmpty {
            let descriptor = FetchDescriptor<EntryModel>(
                predicate: #Predicate<EntryModel> { $0.categoryID == catId && $0.userID == userID },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<EntryModel>(
                predicate: #Predicate<EntryModel> { ($0.categoryID == nil || $0.categoryID == "") && $0.userID == userID },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }
    }

    func inboxCount(userID: String) throws -> Int {
        var descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { ($0.categoryID == nil || $0.categoryID == "") && $0.userID == userID }
        )
        descriptor.fetchLimit = 0
        return try modelContext.fetchCount(descriptor)
    }

    func createEntry(userID: String, transcript: String, title: String?, categoryID: String?, locale: String?, audioLocalPath: String? = nil) throws -> EntryModel {
        let id = UUID().uuidString
        let model = EntryModel(
            id: id,
            userID: userID,
            transcript: transcript,
            title: title ?? "",
            categoryID: categoryID,
            syncStatus: .pendingCreate,
            locale: locale,
            audioLocalPath: audioLocalPath
        )
        modelContext.insert(model)
        try modelContext.save()
        return model
    }

    func searchLocalEntries(userID: String, query: String) throws -> [EntryModel] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = query.lowercased()
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.userID == userID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        return all.filter {
            $0.transcript.lowercased().contains(q) || ($0.title?.lowercased().contains(q) ?? false)
        }
    }

    /// Search across category note bodies.
    func searchCategories(userID: String, query: String) throws -> [CategoryModel] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = query.lowercased()
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.userID == userID && !$0.isArchived },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        return all.filter {
            $0.name.lowercased().contains(q) || $0.noteBody.lowercased().contains(q)
        }
    }

    func updateEntry(id: String, userID: String, transcript: String, title: String?, categoryID: String?, locale: String?) throws {
        var descriptor = FetchDescriptor<EntryModel>(predicate: #Predicate<EntryModel> { $0.id == id && $0.userID == userID })
        descriptor.fetchLimit = 1
        guard let model = try modelContext.fetch(descriptor).first else { return }
        model.transcript = transcript
        model.title = title
        model.categoryID = categoryID
        model.locale = locale
        model.syncStatus = .pendingUpdate
        try modelContext.save()
    }

    func refreshCategoryEntryCount(categoryID: String, userID: String) throws {
        var descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.categoryID == categoryID && $0.userID == userID }
        )
        descriptor.fetchLimit = 0
        let count = try modelContext.fetchCount(descriptor)
        if let cat = try fetchCategory(by: categoryID) {
            cat.entryCount = count
            try modelContext.save()
        }
    }

    // MARK: - Note / Pending entry queries

    /// Fetch pending entries for a category that haven't been merged yet (isPending = true, not deleted).
    func fetchPendingEntries(categoryID: String, userID: String) throws -> [EntryModel] {
        let notDeleted = "pendingDelete"
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> {
                $0.categoryID == categoryID && $0.userID == userID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).filter {
            $0.isPending && $0.syncStatusRaw != notDeleted
        }
    }

    /// Fetch entries that were seen (seenAt != nil) but still pending — candidates for auto-merge.
    func fetchSeenPendingEntries(categoryID: String, userID: String) throws -> [EntryModel] {
        let notDeleted = "pendingDelete"
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> {
                $0.categoryID == categoryID && $0.userID == userID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).filter {
            $0.isPending && $0.seenAt != nil && $0.syncStatusRaw != notDeleted
        }
    }

    /// Update the note body for a category.
    func updateCategoryNoteBody(id: String, noteBody: String, richNoteBody: Data?) throws {
        guard let model = try fetchCategory(by: id) else { return }
        model.noteBody = noteBody
        model.richNoteBody = richNoteBody
        model.lastUpdated = Date()
        model.syncStatus = .pendingUpdate
        try modelContext.save()
    }

    /// Migrate existing entries into note body for a category (first-time migration).
    /// On first run after update, ALL existing entries are treated as reviewed and merged,
    /// since they predate the pending-review feature.
    func migrateEntriesToNoteBody(categoryID: String, userID: String) throws {
        guard let cat = try fetchCategory(by: categoryID) else { return }
        // Only migrate if noteBody is empty (hasn't been migrated yet)
        guard cat.noteBody.isEmpty else { return }

        let entries = try fetchEntries(categoryID: categoryID, userID: userID)
        // Filter out pending-delete entries
        let active = entries.filter { $0.syncStatus != .pendingDelete }
        guard !active.isEmpty else { return }

        // During migration, merge ALL existing entries (they predate the pending system)
        // Build note body from entries (newest first — already sorted by createdAt desc)
        let body = active.map { $0.transcript.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        cat.noteBody = body
        cat.lastUpdated = Date()
        cat.syncStatus = .pendingUpdate

        // Mark all migrated entries as non-pending and schedule deletion
        for entry in active {
            entry.isPending = false
            entry.syncStatus = .pendingDelete
        }

        try modelContext.save()
    }

    // MARK: - Pending sync queries

    func getPendingCreateCategories(userID: String) throws -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.userID == userID && $0.syncStatusRaw == "pendingCreate" }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPendingUpdateCategories(userID: String) throws -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.userID == userID && $0.syncStatusRaw == "pendingUpdate" }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPendingDeleteCategories(userID: String) throws -> [CategoryModel] {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.userID == userID && $0.syncStatusRaw == "pendingDelete" }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPendingCreateEntries(userID: String) throws -> [EntryModel] {
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.userID == userID && $0.syncStatusRaw == "pendingCreate" }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPendingUpdateEntries(userID: String) throws -> [EntryModel] {
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.userID == userID && $0.syncStatusRaw == "pendingUpdate" }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPendingDeleteEntries(userID: String) throws -> [EntryModel] {
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.userID == userID && $0.syncStatusRaw == "pendingDelete" }
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Upsert from server

    func upsertCategory(id: String, userID: String, name: String, entryCount: Int, isUserCreated: Bool, lastUpdated: Date, noteBody: String? = nil) throws {
        if let existing = try fetchCategory(by: id) {
            existing.name = name
            existing.entryCount = entryCount
            existing.lastUpdated = lastUpdated
            existing.syncStatus = .synced
            if let body = noteBody { existing.noteBody = body }
        } else {
            let model = CategoryModel(
                id: id,
                userID: userID,
                name: name,
                entryCount: entryCount,
                isUserCreated: isUserCreated,
                lastUpdated: lastUpdated,
                syncStatus: .synced,
                noteBody: noteBody ?? ""
            )
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    func upsertEntry(id: String, userID: String, transcript: String, title: String?, categoryID: String?, createdAt: Date, locale: String?, isPending: Bool? = nil) throws {
        var descriptor = FetchDescriptor<EntryModel>(predicate: #Predicate<EntryModel> { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.transcript = transcript
            existing.title = title
            existing.categoryID = categoryID
            existing.syncStatus = .synced
            if let pending = isPending { existing.isPending = pending }
        } else {
            let model = EntryModel(
                id: id,
                userID: userID,
                transcript: transcript,
                title: title,
                categoryID: categoryID,
                createdAt: createdAt,
                syncStatus: .synced,
                locale: locale,
                isPending: isPending ?? true
            )
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    /// After process-entry returns server entry: replace local entry by localId with synced entry (server id may differ).
    /// New AI-categorized entries arrive as isPending = true so the user can review them.
    func replaceEntryWithServer(localId: String, serverId: String, userID: String, transcript: String, title: String?, categoryID: String?, createdAt: Date, locale: String?) throws {
        var descriptor = FetchDescriptor<EntryModel>(predicate: #Predicate<EntryModel> { $0.id == localId })
        descriptor.fetchLimit = 1
        if let old = try modelContext.fetch(descriptor).first {
            modelContext.delete(old)
        }
        let model = EntryModel(
            id: serverId,
            userID: userID,
            transcript: transcript,
            title: title,
            categoryID: categoryID,
            createdAt: createdAt,
            syncStatus: .synced,
            locale: locale,
            isPending: true
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func markEntrySynced(id: String, categoryID: String?) throws {
        var descriptor = FetchDescriptor<EntryModel>(predicate: #Predicate<EntryModel> { $0.id == id })
        descriptor.fetchLimit = 1
        guard let model = try modelContext.fetch(descriptor).first else { return }
        model.categoryID = categoryID
        model.syncStatus = .synced
        try modelContext.save()
    }

    func markCategorySynced(id: String) throws {
        guard let model = try fetchCategory(by: id) else { return }
        model.syncStatus = .synced
        try modelContext.save()
    }

    func hardDeleteCategory(id: String) throws {
        guard let model = try fetchCategory(by: id) else { return }
        modelContext.delete(model)
        try modelContext.save()
    }

    func hardDeleteEntry(id: String) throws {
        var descriptor = FetchDescriptor<EntryModel>(predicate: #Predicate<EntryModel> { $0.id == id })
        descriptor.fetchLimit = 1
        guard let model = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(model)
        try modelContext.save()
    }

    // MARK: - Pull reconciliation

    /// Remove local synced categories that no longer exist on the server.
    /// Only deletes `.synced` records — pending local changes are preserved.
    func removeSyncedCategoriesNotIn(serverIDs: Set<String>, userID: String) throws {
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate<CategoryModel> { $0.userID == userID && $0.syncStatusRaw == "synced" }
        )
        let localSynced = try modelContext.fetch(descriptor)
        for cat in localSynced where !serverIDs.contains(cat.id) {
            modelContext.delete(cat)
        }
        try modelContext.save()
    }

    /// Remove local synced entries that no longer exist on the server.
    /// Only deletes `.synced` records — pending local changes are preserved.
    func removeSyncedEntriesNotIn(serverIDs: Set<String>, userID: String) throws {
        let descriptor = FetchDescriptor<EntryModel>(
            predicate: #Predicate<EntryModel> { $0.userID == userID && $0.syncStatusRaw == "synced" }
        )
        let localSynced = try modelContext.fetch(descriptor)
        for entry in localSynced where !serverIDs.contains(entry.id) {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }
}
