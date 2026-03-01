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
    // MARK: - Auth
    var userId: String?

    // MARK: - Data
    var inboxCount: Int = 0

    // MARK: - UI State
    var defaultThoughtLanguage: String = "en-US"

    /// Category IDs that received a new thought via process-entry.
    /// Persisted so the badge survives app restarts.
    var newlySortedCategoryIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(newlySortedCategoryIDs), forKey: "newlySortedCategoryIDs") }
    }

    init() {
        self.newlySortedCategoryIDs = Set(UserDefaults.standard.stringArray(forKey: "newlySortedCategoryIDs") ?? [])
    }

    // MARK: - Actions
    func hydrate(userId: String) {
        self.userId = userId
    }

    func refreshInboxCount(_ count: Int) {
        inboxCount = count
    }
}
