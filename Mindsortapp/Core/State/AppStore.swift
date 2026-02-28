//
//  AppStore.swift
//  Mindsortapp
//
//  @Observable app state, injected via SwiftUI Environment.
//

import Foundation
import SwiftUI

@Observable
final class AppStore {
    // MARK: - Auth & Hydration
    var userId: String?
    var hydrated: Bool = false

    // MARK: - Categories & Entries
    var categories: [Category] = []
    var entries: [Entry] = []
    var inboxCount: Int = 0

    // MARK: - Sync
    var isSyncing: Bool = false

    // MARK: - UI State
    var categoryLastSeen: [String: Date] = [:]
    var appLanguage: String = "en"
    var defaultThoughtLanguage: String = "en-US"

    // MARK: - Auth Actions
    func setUserId(_ id: String?) {
        userId = id
        if id == nil {
            hydrated = false
            categories = []
            entries = []
            inboxCount = 0
        }
    }

    // MARK: - Category Actions
    func setCategories(_ items: [Category]) {
        categories = items
    }

    func addCategory(_ item: Category) {
        categories.append(item)
    }

    func updateCategory(_ item: Category) {
        if let idx = categories.firstIndex(where: { $0.id == item.id }) {
            categories[idx] = item
        }
    }

    func removeCategory(id: String) {
        categories.removeAll { $0.id == id }
    }

    // MARK: - Entry Actions
    func setEntriesForCategory(_ items: [Entry]) {
        entries = items
    }

    func addEntry(_ item: Entry) {
        entries.append(item)
    }

    func updateEntry(_ item: Entry) {
        if let idx = entries.firstIndex(where: { $0.id == item.id }) {
            entries[idx] = item
        }
    }

    func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    // MARK: - Hydration & Refresh
    func hydrate(userId: String) {
        self.userId = userId
        hydrated = true
    }

    func refreshInboxCount(_ count: Int) {
        inboxCount = count
    }

    func markCategorySeen(id: String) {
        categoryLastSeen[id] = Date()
    }

    func setAppLanguage(_ code: String) {
        appLanguage = code
    }

    func setDefaultThoughtLanguage(_ code: String) {
        defaultThoughtLanguage = code
    }
}
