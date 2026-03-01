//
//  EntryModel.swift
//  Mindsortapp
//

import Foundation
import SwiftData

@Model
final class EntryModel {
    @Attribute(.unique) var id: String
    var userID: String
    var transcript: String
    var title: String?
    var categoryID: String?
    var color: String?
    var createdAt: Date
    var syncStatusRaw: String
    var locale: String?
    var audioLocalPath: String?

    /// true while the entry hasn't been reviewed by the user (can still be reassigned).
    var isPending: Bool

    /// Timestamp when the user first saw this pending entry in the category view.
    /// Entries that were seen but not acted on auto-merge on next open.
    var seenAt: Date?

    init(
        id: String,
        userID: String,
        transcript: String,
        title: String? = nil,
        categoryID: String? = nil,
        color: String? = nil,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .synced,
        locale: String? = nil,
        audioLocalPath: String? = nil,
        isPending: Bool = true,
        seenAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.transcript = transcript
        self.title = title
        self.categoryID = categoryID
        self.color = color
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.locale = locale
        self.audioLocalPath = audioLocalPath
        self.isPending = isPending
        self.seenAt = seenAt
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }
}
