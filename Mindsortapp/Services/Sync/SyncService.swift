//
//  SyncService.swift
//  Mindsortapp
//
//  Offline-first sync: push pending changes, then pull from server.
//

import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "Mindsortapp", category: "Sync")

@MainActor
final class SyncService {
    private let modelContext: ModelContext
    private let api: APIService
    private var isSyncing = false

    init(modelContext: ModelContext, api: APIService) {
        self.modelContext = modelContext
        self.api = api
    }

    var syncing: Bool { isSyncing }

    /// Full sync: push then pull. Call from pull-to-refresh or after login.
    func syncAll(userID: String) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let db = DatabaseService(modelContext: modelContext)
        do {
            try await push(userID: userID, db: db)
            try await pull(userID: userID, db: db)
        } catch {
            // Sync errors are non-fatal; local data remains
        }
    }

    /// Fire-and-forget sync after a local write. Use when online.
    func requestSync(userID: String) {
        Task {
            await syncAll(userID: userID)
        }
    }

    // MARK: - Push

    private func push(userID: String, db: DatabaseService) async throws {
        // 1. Pending create categories (failure does not block entries)
        do {
            let pendingCats = try db.getPendingCreateCategories(userID: userID)
            for cat in pendingCats {
                do {
                    _ = try await api.createCategory(name: cat.name, id: cat.id)
                    try db.markCategorySynced(id: cat.id)
                } catch {
                    logger.error("Failed to create category \(cat.id): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to fetch pending categories: \(error.localizedDescription)")
        }

        // 2. Pending create entries (through process-entry for AI categorization)
        do {
            let pendingEntries = try db.getPendingCreateEntries(userID: userID)
            for entry in pendingEntries {
                do {
                    let response = try await api.processEntry(
                        transcript: entry.transcript,
                        locale: entry.locale,
                        categoryId: entry.categoryID
                    )
                    try db.replaceEntryWithServer(
                        localId: entry.id,
                        serverId: response.entry.id,
                        userID: userID,
                        transcript: response.entry.transcript,
                        title: response.entry.title,
                        categoryID: response.entry.categoryID,
                        createdAt: response.entry.createdAt,
                        locale: response.entry.locale
                    )
                    try db.refreshCategoryEntryCount(categoryID: response.category.id, userID: userID)
                } catch {
                    logger.error("process-entry failed for entry \(entry.id): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to fetch pending entries: \(error.localizedDescription)")
        }

        // 3. Pending update categories
        do {
            let updateCats = try db.getPendingUpdateCategories(userID: userID)
            for cat in updateCats {
                do {
                    try await api.renameCategory(id: cat.id, name: cat.name)
                    try db.markCategorySynced(id: cat.id)
                } catch {
                    logger.error("Failed to rename category \(cat.id): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to fetch pending update categories: \(error.localizedDescription)")
        }

        // 4. Pending update entries
        do {
            let updateEntries = try db.getPendingUpdateEntries(userID: userID)
            for entry in updateEntries {
                do {
                    try await api.editEntry(id: entry.id, transcript: entry.transcript, title: entry.title, categoryID: entry.categoryID)
                    try db.markEntrySynced(id: entry.id, categoryID: entry.categoryID)
                } catch {
                    logger.error("Failed to update entry \(entry.id): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to fetch pending update entries: \(error.localizedDescription)")
        }

        // 5. Pending delete entries then categories
        do {
            let deleteEntries = try db.getPendingDeleteEntries(userID: userID)
            for entry in deleteEntries {
                do {
                    try await api.deleteEntry(id: entry.id)
                    try db.hardDeleteEntry(id: entry.id)
                } catch {
                    logger.error("Failed to delete entry \(entry.id): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to fetch pending delete entries: \(error.localizedDescription)")
        }

        do {
            let deleteCats = try db.getPendingDeleteCategories(userID: userID)
            for cat in deleteCats {
                do {
                    try await api.deleteCategory(id: cat.id)
                    try db.hardDeleteCategory(id: cat.id)
                } catch {
                    logger.error("Failed to delete category \(cat.id): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to fetch pending delete categories: \(error.localizedDescription)")
        }
    }

    // MARK: - Pull

    private func pull(userID: String, db: DatabaseService) async throws {
        let serverCategories = try await api.fetchCategories()
        for cat in serverCategories {
            try db.upsertCategory(
                id: cat.id,
                userID: userID,
                name: cat.name,
                entryCount: cat.entryCount,
                isUserCreated: cat.isUserCreated,
                lastUpdated: cat.lastUpdated
            )
        }
        for cat in serverCategories {
            let entries = try await api.fetchEntriesByCategory(categoryId: cat.id)
            for entry in entries {
                try db.upsertEntry(
                    id: entry.id,
                    userID: entry.userID,
                    transcript: entry.transcript,
                    title: entry.title,
                    categoryID: entry.categoryID,
                    createdAt: entry.createdAt,
                    locale: entry.locale
                )
            }
        }
    }
}
