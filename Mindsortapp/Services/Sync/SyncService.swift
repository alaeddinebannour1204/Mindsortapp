//
//  SyncService.swift
//  Mindsortapp
//
//  Offline-first sync with request queuing so process-entry is never skipped.
//

import Foundation
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "Mindsortapp", category: "Sync")

@MainActor
@Observable
final class SyncService {
    private let modelContext: ModelContext
    private let api: APIService
    private var isSyncing = false
    private var pendingSync = false

    var syncing: Bool { isSyncing }

    init(modelContext: ModelContext, api: APIService) {
        self.modelContext = modelContext
        self.api = api
    }

    /// Enqueue a sync. If one is running, run again when it completes.
    func requestSync(userID: String) {
        if isSyncing {
            pendingSync = true
            return
        }
        Task { await runSyncLoop(userID: userID) }
    }

    /// Full sync for pull-to-refresh. Blocks until complete; re-runs if queued.
    func syncAll(userID: String) async {
        await runSyncLoop(userID: userID)
    }

    // MARK: - Sync Loop

    private func runSyncLoop(userID: String) async {
        repeat {
            pendingSync = false
            isSyncing = true
            let db = DatabaseService(modelContext: modelContext)
            do {
                try await push(userID: userID, db: db)
                try await pull(userID: userID, db: db)
            } catch {
                logger.error("Sync failed: \(error.localizedDescription)")
            }
            isSyncing = false
        } while pendingSync
    }

    // MARK: - Push

    private func push(userID: String, db: DatabaseService) async throws {
        // 1. Pending create categories
        do {
            let pendingCats = try db.getPendingCreateCategories(userID: userID)
            for cat in pendingCats {
                do {
                    _ = try await api.createCategory(name: cat.name, id: cat.id)
                    try db.markCategorySynced(id: cat.id)
                } catch {
                    if error.localizedDescription.contains("duplicate") {
                        try? db.markCategorySynced(id: cat.id)
                    } else {
                        logger.error("Failed to create category \(cat.id): \(error.localizedDescription)")
                    }
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
        let serverCategoryIDs = Set(serverCategories.map { $0.id })

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

        try db.removeSyncedCategoriesNotIn(serverIDs: serverCategoryIDs, userID: userID)

        let serverEntries = try await api.fetchAllEntries()
        let serverEntryIDs = Set(serverEntries.map { $0.id })

        for entry in serverEntries {
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

        try db.removeSyncedEntriesNotIn(serverIDs: serverEntryIDs, userID: userID)
    }
}
