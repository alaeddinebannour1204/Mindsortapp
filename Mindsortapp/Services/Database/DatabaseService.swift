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

    func createEntry(userID: String, transcript: String, title: String?, categoryID: String?, locale: String?) throws -> EntryModel {
        let id = UUID().uuidString
        let model = EntryModel(
            id: id,
            userID: userID,
            transcript: transcript,
            title: title ?? "",
            categoryID: categoryID,
            syncStatus: .pendingCreate,
            locale: locale
        )
        modelContext.insert(model)
        try modelContext.save()
        return model
    }

    func markCategorySeen(categoryID: String, userID: String) throws {
        var descriptor = FetchDescriptor<CategoryLastSeen>(
            predicate: #Predicate<CategoryLastSeen> { $0.categoryID == categoryID && $0.userID == userID }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.lastSeenAt = Date()
        } else {
            modelContext.insert(CategoryLastSeen(categoryID: categoryID, userID: userID))
        }
        try modelContext.save()
    }

    func lastSeenDate(categoryID: String, userID: String) throws -> Date? {
        var descriptor = FetchDescriptor<CategoryLastSeen>(
            predicate: #Predicate<CategoryLastSeen> { $0.categoryID == categoryID && $0.userID == userID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.lastSeenAt
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

    func upsertCategory(id: String, userID: String, name: String, entryCount: Int, isUserCreated: Bool, lastUpdated: Date) throws {
        if let existing = try fetchCategory(by: id) {
            existing.name = name
            existing.entryCount = entryCount
            existing.lastUpdated = lastUpdated
            existing.syncStatus = .synced
        } else {
            let model = CategoryModel(
                id: id,
                userID: userID,
                name: name,
                entryCount: entryCount,
                isUserCreated: isUserCreated,
                lastUpdated: lastUpdated,
                syncStatus: .synced
            )
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    func upsertEntry(id: String, userID: String, transcript: String, title: String?, categoryID: String?, createdAt: Date, locale: String?) throws {
        var descriptor = FetchDescriptor<EntryModel>(predicate: #Predicate<EntryModel> { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.transcript = transcript
            existing.title = title
            existing.categoryID = categoryID
            existing.syncStatus = .synced
        } else {
            let model = EntryModel(
                id: id,
                userID: userID,
                transcript: transcript,
                title: title,
                categoryID: categoryID,
                createdAt: createdAt,
                syncStatus: .synced,
                locale: locale
            )
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    /// After process-entry returns server entry: replace local entry by localId with synced entry (server id may differ).
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
            locale: locale
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
