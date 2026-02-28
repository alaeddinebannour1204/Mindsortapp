//
//  SyncCoordinator.swift
//  Mindsortapp
//
//  Shared coordinator with request queuing so process-entry is never skipped.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SyncCoordinator {
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
        Task {
            await runSyncLoop(userID: userID)
        }
    }

    /// Full sync for pull-to-refresh. Blocks until complete; processes queued requests.
    func syncAll(userID: String) async {
        await runSyncLoop(userID: userID)
    }

    private func runSyncLoop(userID: String) async {
        repeat {
            pendingSync = false
            isSyncing = true
            defer { isSyncing = false }
            let sync = SyncService(modelContext: modelContext, api: api)
            await sync.syncAll(userID: userID)
        } while pendingSync
    }
}
