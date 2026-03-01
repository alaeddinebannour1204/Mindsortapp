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

    // MARK: - Actions
    func hydrate(userId: String) {
        self.userId = userId
    }

    func refreshInboxCount(_ count: Int) {
        inboxCount = count
    }
}
