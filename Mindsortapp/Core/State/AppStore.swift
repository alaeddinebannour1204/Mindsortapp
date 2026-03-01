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

    // MARK: - Language

    /// UI language for the app (e.g. "en", "de", "fr", "es").
    var appLanguage: String {
        didSet { UserDefaults.standard.set(appLanguage, forKey: "appLanguage") }
    }

    /// Locale used for speech recognition / recording (e.g. "en-US", "de-DE").
    var defaultThoughtLanguage: String {
        didSet { UserDefaults.standard.set(defaultThoughtLanguage, forKey: "defaultThoughtLanguage") }
    }

    /// Category IDs that received a new thought via process-entry.
    /// Persisted so the badge survives app restarts.
    var newlySortedCategoryIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(newlySortedCategoryIDs), forKey: "newlySortedCategoryIDs") }
    }

    init() {
        self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        self.defaultThoughtLanguage = UserDefaults.standard.string(forKey: "defaultThoughtLanguage") ?? "en-US"
        self.newlySortedCategoryIDs = Set(UserDefaults.standard.stringArray(forKey: "newlySortedCategoryIDs") ?? [])
    }

    // MARK: - Localization

    /// Translate a key using the current app language.
    func t(_ key: String) -> String {
        L.t(key, lang: appLanguage)
    }

    // MARK: - Actions
    func hydrate(userId: String) {
        self.userId = userId
    }

    func refreshInboxCount(_ count: Int) {
        inboxCount = count
    }
}
