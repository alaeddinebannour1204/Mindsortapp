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
    private let store: AppStore
    private var isSyncing = false
    private var pendingSync = false

    var syncing: Bool { isSyncing }
    var lastSyncFailed: Bool = false

    init(modelContext: ModelContext, api: APIService, store: AppStore) {
        self.modelContext = modelContext
        self.api = api
        self.store = store
    }

    /// Enqueue a sync. If one is running, run again when it completes.
    func requestSync(userID: String) {
        if isSyncing {
            pendingSync = true
            return
        }
        Task { await runSyncLoop(userID: userID) }
    }

    /// Full sync for pull-to-refresh.
    /// Runs in an unstructured Task so it survives the `.refreshable` scope.
    func syncAll(userID: String) async {
        // Use withCheckedContinuation to block the refreshable indicator
        // while the detached work runs, but the sync itself is not cancelled
        // when the user lifts their finger.
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                await runSyncLoop(userID: userID)
                continuation.resume()
            }
        }
    }

    // MARK: - Sync Loop

    private func runSyncLoop(userID: String) async {
        repeat {
            pendingSync = false
            isSyncing = true
            let db = DatabaseService(modelContext: modelContext)
            do {
                try Task.checkCancellation()
                try await push(userID: userID, db: db)
                try await pull(userID: userID, db: db)
                lastSyncFailed = false
            } catch is CancellationError {
                // Task was cancelled (e.g. view disappeared) — not a real failure.
                logger.info("Sync cancelled")
            } catch let error as URLError where error.code == .cancelled {
                logger.info("Sync network request cancelled")
            } catch {
                lastSyncFailed = true
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
                    // Upload audio file to Supabase Storage if available
                    var audioStoragePath: String?
                    if let localFileName = entry.audioLocalPath {
                        let localURL = RecordingService.audioDirectory.appendingPathComponent(localFileName)
                        if FileManager.default.fileExists(atPath: localURL.path) {
                            do {
                                audioStoragePath = try await api.uploadAudio(fileURL: localURL, userID: userID)
                            } catch {
                                logger.error("Audio upload failed for \(entry.id), continuing without audio: \(error.localizedDescription)")
                            }
                        }
                    }

                    let response = try await api.processEntry(
                        transcript: entry.transcript,
                        locale: entry.locale,
                        categoryId: entry.categoryID,
                        audioPath: audioStoragePath
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
                    store.newlySortedCategoryIDs.insert(response.category.id)

                    // Delete local audio file after successful sync
                    if let localFileName = entry.audioLocalPath {
                        let localURL = RecordingService.audioDirectory.appendingPathComponent(localFileName)
                        try? FileManager.default.removeItem(at: localURL)
                    }
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
