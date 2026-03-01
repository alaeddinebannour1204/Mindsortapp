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

    // MARK: - Data
    var inboxCount: Int = 0

    // MARK: - UI State
    var categoryLastSeen: [String: Date] = [:]
    var defaultThoughtLanguage: String = "en-US"

    // MARK: - Auth Actions
    func setUserId(_ id: String?) {
        userId = id
        if id == nil {
            hydrated = false
            inboxCount = 0
        }
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

    func setDefaultThoughtLanguage(_ code: String) {
        defaultThoughtLanguage = code
    }
}
